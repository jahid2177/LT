import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_repository.dart';
import 'playlist_dialog.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  static const _remote = MethodChannel('livetv_remote/keys');

  final _repository = PlaylistRepository();
  final _focus = FocusNode(debugLabel: 'TV remote input');
  final _listScroll = ScrollController();

  List<TvChannel> _channels = <TvChannel>[];
  Set<String> _favorites = <String>{};
  VideoPlayerController? _controller;
  int _currentIndex = -1;
  int _highlightIndex = 0;
  int _playbackGeneration = 0;
  bool _loading = true;
  bool _playerLoading = false;
  bool _drawerVisible = false;
  bool _infoVisible = false;
  bool _favoritesOnly = false;
  bool _dialogOpen = false;
  String _playlistUrl = '';
  String _numberBuffer = '';
  String? _playerError;
  Timer? _infoTimer;
  Timer? _numberTimer;

  List<int> get _visibleIndices => <int>[
        for (var i = 0; i < _channels.length; i++)
          if (!_favoritesOnly || _favorites.contains(_channels[i].url)) i,
      ];

  TvChannel? get _currentChannel =>
      _currentIndex >= 0 && _currentIndex < _channels.length
          ? _channels[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _remote.setMethodCallHandler(_handleNativeRemote);
    unawaited(_restore());
  }

  Future<dynamic> _handleNativeRemote(MethodCall call) async {
    if (call.method != 'onRemoteKey' || _dialogOpen) return null;
    switch (call.arguments) {
      case 'channelUp':
        _changeChannel(1);
        break;
      case 'channelDown':
        _changeChannel(-1);
        break;
      case 'guide':
      case 'menu':
        _openDrawer();
        break;
    }
    return null;
  }

  Future<void> _restore() async {
    try {
      final text = await _repository.loadText();
      final url = await _repository.loadUrl();
      final last = await _repository.loadLastChannelUrl();
      final favorites = await _repository.loadFavorites();
      if (!mounted) return;
      _playlistUrl = url ?? '';
      _favorites = favorites;
      if (text != null && text.trim().isNotEmpty) {
        final list = _repository.parse(
          text,
          baseUri: url == null ? null : Uri.tryParse(url),
        );
        setState(() {
          _channels = list;
          _loading = false;
        });
        final index = list.indexWhere((item) => item.url == last);
        _tune(index == -1 ? 0 : index);
      } else {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _playerError = 'Saved playlist could not be loaded: $error';
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _useDemo() async {
    try {
      final text = await rootBundle.loadString('assets/demo_playlist.m3u');
      final channels = _repository.parse(text);
      await _setPlaylist(PlaylistSelection(text: text, channels: channels));
    } catch (error) {
      if (mounted) setState(() => _playerError = 'Demo failed: $error');
    }
  }

  Future<void> _setPlaylist(PlaylistSelection selection) async {
    final selectedUrl = _currentChannel?.url;
    final matchingIndex = selection.channels.indexWhere((e) => e.url == selectedUrl);
    setState(() {
      _channels = selection.channels;
      _playlistUrl = selection.url ?? '';
      _favoritesOnly = false;
      _drawerVisible = false;
      _playerError = null;
    });
    await _repository.storePlaylist(selection.text, url: selection.url);
    if (!mounted) return;
    _tune(matchingIndex == -1 ? 0 : matchingIndex);
  }

  Future<void> _openSettings() async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    final result = await showDialog<PlaylistSelection>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PlaylistDialog(
        repository: _repository,
        currentUrl: _playlistUrl,
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (result != null) {
      try {
        await _setPlaylist(result);
      } catch (error) {
        if (mounted) setState(() => _playerError = 'Cannot save playlist: $error');
      }
    }
    if (mounted) _focus.requestFocus();
  }

  void _tune(int target) {
    if (!mounted || target < 0 || target >= _channels.length) return;
    final generation = ++_playbackGeneration;
    _numberTimer?.cancel();
    final previous = _controller;
    final item = _channels[target];
    final uri = Uri.tryParse(item.url);
    setState(() {
      _currentIndex = target;
      _controller = null;
      _playerError = null;
      _playerLoading = true;
      _drawerVisible = false;
      _numberBuffer = '';
    });
    if (previous != null) unawaited(previous.dispose());
    unawaited(_repository.storeLastChannel(item.url));
    _showInfo();
    if (uri == null) {
      setState(() {
        _playerLoading = false;
        _playerError = 'Invalid channel URL';
      });
      return;
    }
    final isHls = uri.path.toLowerCase().endsWith('.m3u8');
    final next = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    next.addListener(() {
      if (!mounted || generation != _playbackGeneration) return;
      if (next.value.hasError && _playerError == null) {
        setState(() {
          _playerError = next.value.errorDescription ?? 'Stream playback error.';
          _playerLoading = false;
        });
      }
    });
    unawaited(_startPlayback(next, generation));
  }

  Future<void> _startPlayback(VideoPlayerController next, int generation) async {
    try {
      await next.initialize();
      if (!mounted || generation != _playbackGeneration) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _playerLoading = false;
      });
      await next.play();
    } catch (error) {
      if (mounted && generation == _playbackGeneration) {
        setState(() {
          _playerError = 'Playback failed. Check the stream URL/network.\n$error';
          _playerLoading = false;
          _controller = null;
        });
      }
      await next.dispose();
    }
  }

  void _changeChannel(int offset) {
    if (_channels.isEmpty) return;
    final next = wrapChannelIndex(_currentIndex == -1 ? 0 : _currentIndex,
        offset, _channels.length);
    _tune(next);
  }

  void _showInfo() {
    _infoTimer?.cancel();
    if (mounted) setState(() => _infoVisible = true);
    _infoTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _infoVisible = false);
    });
  }

  void _openDrawer() {
    if (_channels.isEmpty) {
      unawaited(_openSettings());
      return;
    }
    final visible = _visibleIndices;
    setState(() {
      _drawerVisible = true;
      _highlightIndex = visible.indexOf(_currentIndex);
      if (_highlightIndex < 0) _highlightIndex = 0;
      _infoVisible = false;
    });
    _ensureHighlightedVisible();
  }

  void _ensureHighlightedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScroll.hasClients) return;
      final desired = (_highlightIndex * 63.0)
          .clamp(0.0, _listScroll.position.maxScrollExtent).toDouble();
      unawaited(_listScroll.animateTo(desired,
          duration: const Duration(milliseconds: 140), curve: Curves.easeOut));
    });
  }

  void _toggleFavorites() {
    final current = _currentChannel;
    if (current == null) return;
    final next = Set<String>.from(_favorites);
    if (!next.add(current.url)) next.remove(current.url);
    setState(() => _favorites = next);
    unawaited(_repository.storeFavorites(next));
    _showInfo();
  }

  void _toggleFilter() {
    setState(() {
      _favoritesOnly = !_favoritesOnly;
      _highlightIndex = 0;
    });
    _ensureHighlightedVisible();
  }

  void _onBack() {
    if (_drawerVisible) {
      setState(() => _drawerVisible = false);
    } else if (_infoVisible) {
      setState(() => _infoVisible = false);
    } else {
      _openDrawer();
    }
    _focus.requestFocus();
  }

  void _onDirectional(int delta) {
    if (!_drawerVisible) {
      _changeChannel(delta);
      return;
    }
    final visible = _visibleIndices;
    if (visible.isEmpty) return;
    setState(() => _highlightIndex = wrapChannelIndex(
        _highlightIndex, delta, visible.length));
    _ensureHighlightedVisible();
  }

  void _onSelect() {
    if (!_drawerVisible) {
      _openDrawer();
      return;
    }
    final visible = _visibleIndices;
    if (visible.isEmpty) return;
    _tune(visible[_highlightIndex.clamp(0, visible.length - 1).toInt()]);
    _focus.requestFocus();
  }

  void _onDigit(String digit) {
    if (_channels.isEmpty) return;
    _numberTimer?.cancel();
    final next = '$_numberBuffer$digit';
    setState(() {
      _numberBuffer = next.length > 4 ? digit : next;
      _infoVisible = true;
    });
    _numberTimer = Timer(const Duration(milliseconds: 1050), () {
      final number = int.tryParse(_numberBuffer);
      if (number != null && number > 0 && number <= _channels.length) {
        _tune(number - 1);
      } else {
        if (mounted) setState(() => _numberBuffer = '');
        _showInfo();
      }
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_dialogOpen || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _onDirectional(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _onDirectional(1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_drawerVisible) {
        setState(() => _drawerVisible = false);
      } else {
        _openDrawer();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_drawerVisible) setState(() => _drawerVisible = false);
      _showInfo();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      _onSelect();
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      _onBack();
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFavorites();
    } else if (key == LogicalKeyboardKey.keyM) {
      unawaited(_openSettings());
    } else if (RegExp(r'^\d$').hasMatch(event.character ?? key.keyLabel)) {
      _onDigit(event.character ?? key.keyLabel);
    } else {
      return KeyEventResult.ignored; // especially volume is handled by Android
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    _numberTimer?.cancel();
    _playbackGeneration++;
    _remote.setMethodCallHandler(null);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    _focus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_dialogOpen) _onBack();
      },
      child: Scaffold(
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildPlayer(),
              if (_infoVisible && _currentChannel != null && !_drawerVisible)
                _buildInfoOverlay(),
              if (_drawerVisible) _buildChannelDrawer(),
              if (_numberBuffer.isNotEmpty)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE8202540),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Text('Channel $_numberBuffer',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_channels.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF1B1547), Color(0xFF070C17)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.live_tv_rounded, size: 86, color: Color(0xFFAA9BFF)),
                const SizedBox(height: 18),
                const Text('LIVE TV REMOTE',
                    style: TextStyle(fontSize: 43, fontWeight: FontWeight.w800,
                        letterSpacing: 2.5)),
                const SizedBox(height: 12),
                const Text('TV-style channel surfing with your remote',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Color(0xFFB8C3D9))),
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add my M3U channels'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _useDemo,
                      icon: const Icon(Icons.ondemand_video),
                      label: const Text('Load playback demo'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('The demo streams are sample videos, not live TV channels.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF93A0B8))),
                if (_playerError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_playerError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF9999))),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final video = _controller;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: Colors.black),
        if (video != null && video.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: video.value.aspectRatio > 0
                  ? video.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(video),
            ),
          ),
        if (_playerLoading)
          const Center(child: CircularProgressIndicator(strokeWidth: 4)),
        if (_playerError != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 630),
              decoration: BoxDecoration(
                color: const Color(0xF01A2030),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                const Icon(Icons.signal_wifi_statusbar_connected_no_internet_4,
                    size: 52, color: Color(0xFFFF9999)),
                const SizedBox(height: 14),
                Text(_playerError!, textAlign: TextAlign.center),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: () => _tune(_currentIndex),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry stream'),
                ),
              ]),
            ),
          ),
        Positioned(
          right: 26,
          top: 22,
          child: Opacity(
            opacity: _infoVisible ? 1 : 0.55,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.circle, color: Color(0xFFFF555E), size: 10),
                SizedBox(width: 7),
                Text('TV', style: TextStyle(fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoOverlay() {
    final channel = _currentChannel!;
    return IgnorePointer(
      ignoring: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 23),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00131A30), Color(0xF5080C18)],
            ),
          ),
          child: Row(children: <Widget>[
            Container(
              width: 72, height: 65,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF6D53DC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_currentIndex + 1}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('${channel.group}  •  ${_channels.length} channels',
                      style: const TextStyle(fontSize: 15, color: Color(0xFFC1CEE3))),
                  const SizedBox(height: 6),
                  const Text('CH +/− change  •  OK guide  •  F favorite  •  M playlists',
                      style: TextStyle(color: Color(0xFF91A2C4), fontSize: 13)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Favorite (F)',
              onPressed: _toggleFavorites,
              icon: Icon(_favorites.contains(channel.url)
                  ? Icons.star : Icons.star_border),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Channel guide',
              onPressed: _openDrawer,
              icon: const Icon(Icons.list),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildChannelDrawer() {
    final indices = _visibleIndices;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 405,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xF50F1525),
          border: Border.all(color: const Color(0xFF343C59)),
          borderRadius: BorderRadius.circular(19),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x99000000), blurRadius: 32),
          ],
        ),
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 8, 12),
            child: Row(children: <Widget>[
              const Icon(Icons.live_tv, color: Color(0xFFAFA0FF)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('CHANNEL GUIDE',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              IconButton(
                onPressed: _toggleFilter,
                tooltip: _favoritesOnly ? 'Show all' : 'Favorites only',
                icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
              ),
              IconButton(
                onPressed: _openSettings,
                tooltip: 'Manage playlist',
                icon: const Icon(Icons.settings),
              ),
              IconButton(
                onPressed: () => setState(() => _drawerVisible = false),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _favoritesOnly ? '${indices.length} favorites' : '${indices.length} channels',
                style: const TextStyle(color: Color(0xFF9DAEC9)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: indices.isEmpty
                ? const Center(child: Text('No favorites yet. Press F while watching.',
                    textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _listScroll,
                    itemCount: indices.length,
                    itemExtent: 63,
                    itemBuilder: (context, listIndex) {
                      final channelIndex = indices[listIndex];
                      final channel = _channels[channelIndex];
                      final highlighted = listIndex == _highlightIndex;
                      final playing = channelIndex == _currentIndex;
                      return InkWell(
                        onTap: () => _tune(channelIndex),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? const Color(0xFF5946A8)
                                : playing ? const Color(0xFF242D48) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: highlighted ? Border.all(color: const Color(0xFFBDAEFF), width: 1.5) : null,
                          ),
                          child: Row(children: <Widget>[
                            SizedBox(
                              width: 40,
                              child: Text('${channelIndex + 1}',
                                  style: const TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(channel.name, maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(channel.group,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11,
                                          color: Color(0xFFADB9D2))),
                                ],
                              ),
                            ),
                            if (_favorites.contains(channel.url))
                              const Icon(Icons.star, color: Color(0xFFFFCC63), size: 19),
                            if (playing) ...<Widget>[
                              const SizedBox(width: 5),
                              const Icon(Icons.graphic_eq, size: 20, color: Color(0xFFBEADFF)),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(13),
            child: Text('↑ ↓ highlight  •  OK watch  •  ← close  •  MENU guide',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF97A9C8))),
          ),
        ]),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import '../services/m3u_parser.dart';
import '../services/channel_identity.dart';
import '../services/playlist_repository.dart';
import '../services/crash_reporter.dart';
import '../services/guide_focus_navigation.dart';
import '../services/screen_awake_policy.dart';
import 'playlist_dialog.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> with WidgetsBindingObserver {
  static const _remote = MethodChannel('livetv_remote/keys');
  static const _screenAwake = MethodChannel('livetv_remote/screen_awake');
  bool? _lastScreenAwakeRequest;

  bool get _keepAwakeDesired => shouldKeepScreenAwake(
        appIsForeground: _foreground,
        channelSelected: _currentIndex >= 0,
        waitingForVideo: _playerLoading,
        playerAttached: _controller != null,
        hasPlaybackError: _playerError != null,
      );

  void _syncScreenAwake({bool force = false}) {
    final enabled = _keepAwakeDesired;
    if (!force && _lastScreenAwakeRequest == enabled) return;
    _lastScreenAwakeRequest = enabled;
    unawaited(_requestScreenAwake(enabled));
  }

  Future<void> _requestScreenAwake(bool enabled) async {
    try {
      await _screenAwake.invokeMethod<void>('setKeepAwake', enabled);
    } catch (error, stack) {
      // A missing MethodChannel should not crash video playback.
      CrashReporter.error('Keep Screen On', error, stack);
    }
  }

  final _repository = PlaylistRepository();
  final _focus = FocusNode(debugLabel: 'TV remote input');
  final _listScroll = ScrollController();
  GuideSection _guideSection = GuideSection.channels;
  int _toolbarIndex = 0;
  static const _guideActionCount = 5;

  List<TvChannel> _channels = <TvChannel>[];
  Set<String> _favorites = <String>{};
  VideoPlayerController? _controller;
  VideoPlayerController? _activePlayer;
  // Serializing ExoPlayer initialization/disposal avoids overlapping decoders
  // on TV chipsets that only support one hardware video decoder.
  Future<void> _playbackTask = Future<void>.value();
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
  String? _preferredUrl;
  String? _preferredId;
  String? _githubEtag;
  bool _hasValidatedOnlineCache = false;
  bool _foreground = true;
  bool _onlineConfirmed = false;
  DateTime? _lastSyncCheck;
  Timer? _refreshTimer;
  static const _refreshInterval = Duration(minutes: 2);
  String? _sourceError;
  String? _cachedPlaylistText;
  bool _refreshing = false;
  int _selectionEpoch = 0;
  String _numberBuffer = '';
  String? _playerError;
  Timer? _infoTimer;
  Timer? _numberTimer;

  List<int> get _visibleIndices => <int>[
        for (var i = 0; i < _channels.length; i++)
          if (!_favoritesOnly || _favorites.contains(stableChannelKey(_channels, i))) i,
      ];

  TvChannel? get _currentChannel =>
      _currentIndex >= 0 && _currentIndex < _channels.length
          ? _channels[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    CrashReporter.stage('LiveTvScreen.initState');
    _remote.setMethodCallHandler(_handleNativeRemote);
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_foreground && !_dialogOpen &&
          _playlistUrl == PlaylistRepository.defaultChannelsUrl) {
        unawaited(_refreshChannels(_playlistUrl));
      }
    });
    unawaited(_restore());
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncScreenAwake();
    if (_foreground && _playlistUrl == PlaylistRepository.defaultChannelsUrl &&
        (_lastSyncCheck == null ||
         DateTime.now().difference(_lastSyncCheck!) > const Duration(seconds: 30))) {
      unawaited(_refreshChannels(_playlistUrl));
    }
  }

  void _restoreFavoriteIdentities(Set<String> oldUrls) {
    if (oldUrls.isEmpty) return;
    var changed = false;
    for (var i = 0; i < _channels.length; i++) {
      if (oldUrls.contains(_channels[i].url)) {
        changed = _favorites.add(stableChannelKey(_channels, i)) || changed;
      }
    }
    if (changed) unawaited(_repository.storeFavoriteIds(_favorites));
  }

  int _savedIndex(List<TvChannel> channels) {
    var index = channelIndexForKey(channels, _preferredId);
    if (index < 0) index = channels.indexWhere((c) => c.url == _preferredUrl);
    return index < 0 ? 0 : index;
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

  // Do not start an unverified HLS stream automatically during Activity
  // creation. Some TV firmware terminates the process in a native decoder
  // before Flutter can display or catch an error. Show a usable guide first.
  void _showStartupGuide(int preferredIndex) {
    if (!mounted || _channels.isEmpty) return;
    setState(() {
      _currentIndex = -1;
      _highlightIndex = preferredIndex.clamp(0, _channels.length - 1).toInt();
      _drawerVisible = true;
      _guideSection = GuideSection.channels;
      _toolbarIndex = 0;
      _playerLoading = false;
      _infoVisible = false;
    });
    _ensureHighlightedVisible();
    _syncScreenAwake();
  }

  Future<void> _restore() async {
    CrashReporter.stage('Channel cache restore begin');
    try {
      final cached = await _repository.loadText();
      final storedUrl = await _repository.loadUrl();
      final last = await _repository.loadLastChannelUrl();
      final lastId = await _repository.loadLastChannelId();
      final oldFavorites = await _repository.loadFavorites();
      final favorites = await _repository.loadFavoriteIds();
      if (!mounted) return;

      // GitHub is ALWAYS the primary startup source, even after an older
      // version of the app saved an imported/temporary M3U URL.
      const sourceUrl = PlaylistRepository.defaultChannelsUrl;
      _playlistUrl = sourceUrl;
      _preferredUrl = last;
      _preferredId = lastId;
      _favorites = favorites;
      final compatibleCache = storedUrl == sourceUrl &&
          cached != null && cached.trim().isNotEmpty;
      if (compatibleCache) {
        try {
          final channels = _repository.parse(cached, baseUri: Uri.parse(sourceUrl));
          _githubEtag = await _repository.loadGithubEtag();
          _hasValidatedOnlineCache = true;
          if (!mounted) return;
          _cachedPlaylistText = cached;
          setState(() {
            _channels = channels;
            _loading = false;
          });
          _restoreFavoriteIdentities(oldFavorites);
          _showStartupGuide(_savedIndex(channels));
        } catch (error) {
          debugPrint('Stored GitHub JSON was invalid: $error');
        }
      }
      // Offline fallback is a snapshot only, never the authoritative source.
      if (_channels.isEmpty) {
        try {
          final text = await _repository.loadBundledChannels();
          final channels = _repository.parse(text);
          if (!mounted) return;
          _cachedPlaylistText = text;
          setState(() {
            _channels = channels;
            _loading = false;
          });
          _restoreFavoriteIdentities(oldFavorites);
          _showStartupGuide(_savedIndex(channels));
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _sourceError = 'Offline fallback cannot be opened: $error';
          });
        }
      }
      CrashReporter.stage('Channel list displayed; requesting GitHub refresh');
      // Always check GitHub on launch, including when saved data exists.
      unawaited(_refreshChannels(sourceUrl));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sourceError = 'Unable to load saved channels: $error';
      });
      CrashReporter.error('Channel cache restore', error);
      // A failed preference read must not prevent a fresh GitHub attempt.
      unawaited(_refreshChannels(PlaylistRepository.defaultChannelsUrl));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _refreshChannels(String url) async {
    if (_refreshing || url.isEmpty || !mounted) return;
    final epoch = _selectionEpoch;
    final primary = url == PlaylistRepository.defaultChannelsUrl;
    _lastSyncCheck = DateTime.now();
    CrashReporter.stage('GitHub JSON refresh starting');
    setState(() {
      _refreshing = true;
      _sourceError = null;
    });
    try {
      final result = await _repository.fetchPlaylistWithMetadata(
        url, etag: primary && _cachedPlaylistText != null ? _githubEtag : null,
      );
      if (!mounted || epoch != _selectionEpoch || url != _playlistUrl) return;
      if (result.notModified) {
        setState(() {
          _onlineConfirmed = true;
          _loading = false;
        });
        return;
      }
      final text = result.text!;
      final channels = _repository.parse(text, baseUri: Uri.parse(url));
      if (!mounted || epoch != _selectionEpoch || url != _playlistUrl) return;
      if (_cachedPlaylistText != text || _channels.isEmpty ||
          (primary && !_hasValidatedOnlineCache)) {
        await _setPlaylist(
          PlaylistSelection(text: text, url: url, channels: channels),
          fromRefresh: true,
        );
      }
      if (!mounted || epoch != _selectionEpoch || url != _playlistUrl) return;
      if (primary) {
        _hasValidatedOnlineCache = true;
        _githubEtag = result.etag;
        await _repository.storeGithubEtag(result.etag);
      }
      CrashReporter.stage('GitHub JSON refresh successful');
      if (mounted) setState(() {
        _onlineConfirmed = true;
        _loading = false;
      });
    } catch (error, stack) {
      CrashReporter.error('GitHub JSON fetch failure', error, stack);
      if (mounted && epoch == _selectionEpoch && url == _playlistUrl) {
        setState(() {
          _loading = false;
          _sourceError = 'GitHub update failed: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _useBundledChannels() async {
    try {
      final text = await _repository.loadBundledChannels();
      final channels = _repository.parse(text);
      if (!mounted) return;
      await _setPlaylist(PlaylistSelection(
        text: text,
        url: PlaylistRepository.defaultChannelsUrl,
        channels: channels,
      ));
    } catch (error) {
      if (mounted) setState(() => _playerError = 'Bundled channels failed: $error');
    }
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

  Future<void> _setPlaylist(PlaylistSelection selection,
      {bool fromRefresh = false}) async {
    if (!fromRefresh) _selectionEpoch++;
    if (!mounted) return;
    final oldChannels = _channels;
    final oldIndex = _currentIndex;
    final oldUrl = _currentChannel?.url;
    final activeKey = oldIndex >= 0 && oldIndex < oldChannels.length
        ? stableChannelKey(oldChannels, oldIndex) : _preferredId;
    final matchingIndex = channelIndexForKey(selection.channels, activeKey);
    final oldVisible = _visibleIndices;
    final oldHighlightKey = _drawerVisible && _highlightIndex < oldVisible.length
        ? stableChannelKey(oldChannels, oldVisible[_highlightIndex]) : null;
    final oldHighlightUrl = _drawerVisible && _highlightIndex < oldVisible.length
        ? oldChannels[oldVisible[_highlightIndex]].url : null;
    final playing = oldIndex >= 0;
    final streamChanged = playing && matchingIndex >= 0 &&
        selection.channels[matchingIndex].url != oldUrl;

    // If there was no stable ID in an older version, URL provides one-time
    // migration. From then on, channel identity is independent of the URL.
    final highlightIndex = channelIndexForKey(selection.channels, oldHighlightKey);
    final migratedHighlight = highlightIndex >= 0 ? highlightIndex :
        selection.channels.indexWhere((e) => e.url == oldHighlightUrl);
    final matchedKey = matchingIndex >= 0
        ? stableChannelKey(selection.channels, matchingIndex) : null;
    final newVisible = <int>[
      for (var i = 0; i < selection.channels.length; i++)
        if (!_favoritesOnly ||
            _favorites.contains(stableChannelKey(selection.channels, i))) i,
    ];
    final nextHighlight = newVisible.indexOf(migratedHighlight);

    setState(() {
      _channels = selection.channels;
      _cachedPlaylistText = selection.text;
      _playlistUrl = selection.url ?? '';
      _playerError = null;
      _sourceError = null;
      _loading = false;
      if (fromRefresh) {
        _currentIndex = playing && matchingIndex >= 0 ? matchingIndex : -1;
        if (playing && matchingIndex < 0) {
          _drawerVisible = true;
          _controller = null;
          _playerLoading = false;
        }
        // Preserve channel-guide focus when names or URLs are updated.
        if (_drawerVisible && nextHighlight >= 0) {
          _highlightIndex = nextHighlight;
        } else if (_drawerVisible && _channels.isNotEmpty) {
          _highlightIndex = 0;
        }
        if (_drawerVisible && newVisible.isEmpty) {
          _guideSection = GuideSection.toolbar;
        }
      } else {
        _favoritesOnly = false;
        _drawerVisible = false;
      }
    });
    _syncScreenAwake();
    if (matchedKey != null) _preferredId = matchedKey;
    if (!fromRefresh) {
      _githubEtag = null;
      _hasValidatedOnlineCache = false;
      _onlineConfirmed = false;
    }

    if (fromRefresh) {
      if (playing && matchingIndex < 0) {
        _playbackGeneration++;
        _queuePlayerCleanup();
      } else if (streamChanged) {
        // New URL for SAME logical channel: retune serially; do not keep
        // playing an expired token, and never allocate two decoders together.
        _tune(matchingIndex);
      }
      _ensureHighlightedVisible();
    } else if (selection.channels.isNotEmpty) {
      final first = matchingIndex < 0 ? 0 : matchingIndex;
      _tune(first);
    }
    await _repository.storePlaylist(selection.text, url: selection.url);
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

  Future<void> _saveLastChannel(String url, String identity) async {
    try {
      await _repository.storeLastChannelId(identity);
      await _repository.storeLastChannel(url);
    } catch (error) {
      debugPrint('Cannot remember channel: $error');
    }
  }

  void _tune(int target) {
    if (!mounted || target < 0 || target >= _channels.length) return;
    CrashReporter.stage('Tuning channel ${target + 1} (without URL)');
    final generation = ++_playbackGeneration;
    _numberTimer?.cancel();
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
    _syncScreenAwake(); // Keep TV on while the stream loads, even before video frames arrive.
    final identity = stableChannelKey(_channels, target);
    _preferredId = identity;
    _preferredUrl = item.url;
    unawaited(_saveLastChannel(item.url, identity));
    _showInfo();
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      setState(() {
        _playerLoading = false;
        _playerError = 'Invalid HTTP(S) channel URL';
      });
      _syncScreenAwake();
      _queuePlayerCleanup();
      return;
    }
    // All native player operations happen in the same queue. A rapid channel
    // change invalidates old requests without overlapping MediaCodec instances.
    _playbackTask = _playbackTask
        .catchError((Object error, StackTrace trace) {
          debugPrint('Player queue recovered: $error');
        })
        .then((_) => _startPlaybackSerial(uri, generation));
  }

  void _queuePlayerCleanup() {
    _playbackTask = _playbackTask
        .catchError((Object error, StackTrace trace) {
          debugPrint('Player cleanup queue recovered: $error');
        })
        .then((_) => _releaseActivePlayer());
  }

  Future<void> _releaseActivePlayer() async {
    final old = _activePlayer;
    _activePlayer = null;
    if (old == null) return;
    try {
      await old.dispose();
    } catch (error) {
      debugPrint('Video player dispose error: $error');
    }
  }

  Future<void> _startPlaybackSerial(Uri uri, int generation) async {
    CrashReporter.stage('Native video player initialization begin');
    // Dispose a previous player BEFORE allocating a new hardware decoder.
    await _releaseActivePlayer();
    if (!mounted || generation != _playbackGeneration) return;
    VideoPlayerController? next;
    var ready = false;
    try {
      final isHls = uri.path.toLowerCase().endsWith('.m3u8');
      final player = VideoPlayerController.networkUrl(
        uri,
        formatHint: isHls ? VideoFormat.hls : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      next = player;
      _activePlayer = player;
      player.addListener(() {
        if (!mounted || generation != _playbackGeneration) return;
        if (player.value.hasError && _playerError == null) {
          setState(() {
            _playerError = player.value.errorDescription ?? 'Stream playback error.';
            _playerLoading = false;
          });
          _syncScreenAwake();
        }
      });
      await player.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || generation != _playbackGeneration) return;
      setState(() {
        _controller = next;
        _playerLoading = false;
      });
      _syncScreenAwake();
      await player.play();
      ready = true;
      CrashReporter.stage('Native video player playback started');
    } catch (error, trace) {
      CrashReporter.error('Video player failure', error, trace);
      debugPrint('TV playback error: $error\n$trace');
      if (mounted && generation == _playbackGeneration) {
        setState(() {
          _playerError = 'Playback failed. Check the stream URL/TV codec.\n$error';
          _playerLoading = false;
          _controller = null;
        });
        _syncScreenAwake();
      }
    } finally {
      if (!ready && next != null) {
        if (identical(_activePlayer, next)) _activePlayer = null;
        try {
          await next.dispose();
        } catch (error) {
          debugPrint('Failed to release unusable TV player: $error');
        }
      }
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
      _guideSection = visible.isEmpty ? GuideSection.toolbar : GuideSection.channels;
      _toolbarIndex = 0;
      _highlightIndex = visible.indexOf(_currentIndex);
      if (_highlightIndex < 0) _highlightIndex = 0;
      _infoVisible = false;
    });
    _ensureHighlightedVisible();
    _focus.requestFocus();
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
    final key = stableChannelKey(_channels, _currentIndex);
    if (!next.add(key)) next.remove(key);
    setState(() => _favorites = next);
    unawaited(_repository.storeFavoriteIds(next));
    _showInfo();
  }

  void _toggleFilter() {
    setState(() {
      _favoritesOnly = !_favoritesOnly;
      _highlightIndex = 0;
    });
    if (_visibleIndices.isEmpty) {
      _guideSection = GuideSection.toolbar;
    }
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

  void _moveGuideFocus(GuideDirection direction) {
    final selection = moveGuideSelection(
      selection: GuideSelection(
        section: _guideSection,
        actionIndex: _toolbarIndex,
        channelIndex: _highlightIndex,
      ),
      direction: direction,
      actionCount: _guideActionCount,
      channelCount: _visibleIndices.length,
    );
    if (selection.closeGuide) {
      setState(() => _drawerVisible = false);
      return;
    }
    setState(() {
      _guideSection = selection.section;
      _toolbarIndex = selection.actionIndex;
      _highlightIndex = selection.channelIndex;
    });
    if (_guideSection == GuideSection.channels) _ensureHighlightedVisible();
  }

  void _onDirectional(int delta) {
    if (_drawerVisible) {
      _moveGuideFocus(delta < 0 ? GuideDirection.up : GuideDirection.down);
    } else {
      _changeChannel(delta);
    }
  }

  void _activateToolbarAction(int index) {
    switch (index) {
      case 0:
        _toggleFilter();
        break;
      case 1:
        if (_playlistUrl.isNotEmpty && !_refreshing) {
          unawaited(_refreshChannels(_playlistUrl));
        }
        break;
      case 2:
        unawaited(CrashReporter.openFinder());
        break;
      case 3:
        unawaited(_openSettings());
        break;
      case 4:
        setState(() => _drawerVisible = false);
        break;
    }
    if (mounted && !_dialogOpen) _focus.requestFocus();
  }

  void _onSelect() {
    if (!_drawerVisible) {
      _openDrawer();
      return;
    }
    if (_guideSection == GuideSection.toolbar) {
      _activateToolbarAction(_toolbarIndex);
      return;
    }
    final visible = _visibleIndices;
    if (visible.isEmpty) {
      setState(() => _guideSection = GuideSection.toolbar);
      return;
    }
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
        _moveGuideFocus(GuideDirection.left);
      } else {
        _openDrawer();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_drawerVisible) {
        _moveGuideFocus(GuideDirection.right);
      } else {
        _showInfo();
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _infoTimer?.cancel();
    _numberTimer?.cancel();
    _playbackGeneration++;
    unawaited(_requestScreenAwake(false));
    _remote.setMethodCallHandler(null);
    _queuePlayerCleanup();
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
              ExcludeFocus(excluding: _drawerVisible, child: _buildPlayer()),
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
                      label: const Text('Manage JSON / M3U channels'),
                    ),
                    if (_playlistUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _refreshing
                            ? null
                            : () => unawaited(_refreshChannels(_playlistUrl)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry online channels'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _useBundledChannels,
                      icon: const Icon(Icons.offline_pin),
                      label: const Text('Load 513 bundled channels'),
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
                if (_sourceError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_sourceError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF9999))),
                  ),
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
        if (_currentIndex < 0 && !_playerLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(left: 410),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.live_tv_rounded, size: 66, color: Color(0xFFAFA0FF)),
                  SizedBox(height: 16),
                  Text('LIVE TV REMOTE',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Select a channel with ↑ ↓ and press OK to watch',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 19, color: Color(0xFFB8C3D9))),
                ],
              ),
            ),
          ),
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
              icon: Icon(_favorites.contains(stableChannelKey(_channels, _currentIndex))
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

  // Keys are handled by the parent Focus widget. These buttons intentionally
  // exclude Flutter's automatic focus traversal so inexpensive TV remotes work
  // predictably even if a player surface would otherwise steal focus.
  Widget _guideAction({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final selected = _guideSection == GuideSection.toolbar &&
        _toolbarIndex == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          label: label,
          button: true,
          selected: selected,
          enabled: onPressed != null,
          child: ExcludeFocus(
            child: Tooltip(
              message: label,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('guide_action_$index'),
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 115),
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? const Color(0xFF3659C8)
                          : const Color(0xFF222B45),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFF7FAFF)
                            : const Color(0xFF46526B),
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? const [BoxShadow(color: Color(0x885E90FF), blurRadius: 14)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: onPressed == null
                        ? const Color(0xFF79859C)
                        : Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelDrawer() {
    final indices = _visibleIndices;
    final listFocused = _guideSection == GuideSection.channels;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 440,
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
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
            child: Row(children: <Widget>[
              const Icon(Icons.live_tv, color: Color(0xFFAFA0FF)),
              const SizedBox(width: 9),
              const Text('CHANNEL GUIDE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const Spacer(),
              if (_guideSection == GuideSection.toolbar)
                const Text('← →  OK',
                    style: TextStyle(color: Color(0xFFBCD2FF), fontSize: 14)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Row(children: <Widget>[
              _guideAction(
                index: 0,
                icon: _favoritesOnly ? Icons.star : Icons.star_border,
                label: _favoritesOnly ? 'Show all channels' : 'Favorites only',
                onPressed: _toggleFilter,
              ),
              _guideAction(
                index: 1,
                icon: Icons.refresh,
                label: 'Refresh channels from GitHub',
                onPressed: _playlistUrl.isEmpty || _refreshing
                    ? null : () => unawaited(_refreshChannels(_playlistUrl)),
              ),
              _guideAction(
                index: 2,
                icon: Icons.bug_report_outlined,
                label: 'Crash Finder',
                onPressed: () => unawaited(CrashReporter.openFinder()),
              ),
              _guideAction(
                index: 3,
                icon: Icons.settings,
                label: 'Settings and playlists',
                onPressed: _openSettings,
              ),
              _guideAction(
                index: 4,
                icon: Icons.close,
                label: 'Close channel guide',
                onPressed: () => setState(() => _drawerVisible = false),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _sourceError != null ? 'Offline / GitHub unavailable • saved list shown'
                  : _refreshing ? 'Checking GitHub for channel updates…'
                  : _favoritesOnly ? '${indices.length} favorites'
                  : _playlistUrl == PlaylistRepository.defaultChannelsUrl
                    ? '${indices.length} channels • ${_onlineConfirmed ? 'GitHub synced' : 'saved copy • syncing'} • auto-refresh 2 min'
                    : '${indices.length} channels • custom playlist',
                style: const TextStyle(color: Color(0xFF9DAEC9)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: indices.isEmpty
                ? const Center(child: Text(
                    'No favorites yet. Use ← → at the top to select Show All.',
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
                      return ExcludeFocus(
                        child: InkWell(
                          onTap: () => _tune(channelIndex),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: highlighted
                                  ? (listFocused ? const Color(0xFF5946A8)
                                      : const Color(0xFF303A5D))
                                  : playing ? const Color(0xFF242D48) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: highlighted && listFocused
                                  ? Border.all(color: const Color(0xFFDDD2FF), width: 2)
                                  : null,
                            ),
                            child: Row(children: <Widget>[
                              SizedBox(
                                width: 40,
                                child: Text('${channelIndex + 1}',
                                    style: const TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (channel.logo.isNotEmpty) ...<Widget>[
                                Image.network(
                                  channel.logo,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.tv, size: 27),
                                ),
                                const SizedBox(width: 9),
                              ],
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
                              if (_favorites.contains(stableChannelKey(_channels, channelIndex)))
                                const Icon(Icons.star, color: Color(0xFFFFCC63), size: 19),
                              if (playing) ...<Widget>[
                                const SizedBox(width: 5),
                                const Icon(Icons.graphic_eq, size: 20,
                                    color: Color(0xFFBEADFF)),
                              ],
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('↑ from first channel → toolbar • ← → choose icon • OK select • BACK close',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF97A9C8))),
          ),
        ]),
      ),
    );
  }

}

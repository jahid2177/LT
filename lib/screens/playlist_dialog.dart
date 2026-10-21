import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/playlist_repository.dart';

class PlaylistSelection {
  const PlaylistSelection({
    required this.text,
    required this.channels,
    this.url,
  });

  final String text;
  final List<TvChannel> channels;
  final String? url;
}

/// URL, local file and clipboard/text entry. File picker support depends on
/// the Android TV firmware having a document provider installed.
class PlaylistDialog extends StatefulWidget {
  const PlaylistDialog({
    super.key,
    required this.repository,
    required this.currentUrl,
  });

  final PlaylistRepository repository;
  final String currentUrl;

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final _url = TextEditingController();
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url.text = widget.currentUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<PlaylistSelection> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await operation();
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fromUrl() => _submit(() async {
        final url = _url.text.trim();
        final text = await widget.repository.fetchPlaylist(url);
        return PlaylistSelection(
          text: text,
          url: url,
          channels: widget.repository.parse(text, baseUri: Uri.parse(url)),
        );
      });

  void _fromText() => _submit(() async {
        final text = _text.text;
        return PlaylistSelection(
          text: text,
          channels: widget.repository.parse(text),
        );
      });

  void _fromFile() => _submit(() async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: <String>['m3u', 'm3u8', 'txt'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          throw const FormatException('File selection cancelled.');
        }
        final file = result.files.single;
        final bytes = file.bytes ??
            (file.path == null ? null : await File(file.path!).readAsBytes());
        if (bytes == null) {
          throw const FormatException('Cannot read the selected file.');
        }
        if (bytes.length > 5 * 1024 * 1024) {
          throw const FormatException('Playlist exceeds 5 MB.');
        }
        final text = utf8.decode(bytes, allowMalformed: true);
        return PlaylistSelection(
          text: text,
          channels: widget.repository.parse(text),
        );
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
      backgroundColor: const Color(0xFF171C2C),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.live_tv, color: Color(0xFFA99BFF), size: 29),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Manage TV channels',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Import an M3U playlist of channels you are authorized to watch. '
                'An HLS .m3u8 video URL on its own is not a channel list.',
                style: TextStyle(color: Color(0xFFADB7CE)),
              ),
              const SizedBox(height: 22),
              const Text('M3U playlist URL'),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://provider.example/playlist.m3u',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                onSubmitted: (_) => _fromUrl(),
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _fromUrl,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Load from URL'),
                ),
              ),
              const SizedBox(height: 11),
              Row(children: <Widget>[
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 11),
              OutlinedButton.icon(
                onPressed: _busy ? null : _fromFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Import .m3u file from device'),
              ),
              const SizedBox(height: 16),
              const Text('Paste M3U text (alternative for TVs without file picker)'),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                enabled: !_busy,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '#EXTM3U\n#EXTINF:-1 group-title="News",News Channel\nhttps://example.com/live.m3u8',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _fromText,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Use pasted playlist'),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A))),
              ],
              if (_busy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

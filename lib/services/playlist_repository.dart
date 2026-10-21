import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/channel.dart';
import 'm3u_parser.dart';
import 'json_channel_parser.dart';

class PlaylistRepository {
  PlaylistRepository([this._parser = const M3uParser()]);

  final M3uParser _parser;
  /// Default GitHub source supplied by the user; loaded on first startup.
  static const defaultChannelsUrl =
      'https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json';

  /// Bundled 513-entry channel list supplied as README.json by the user.
  /// The online GitHub URL remains the primary source for updates.
  static const bundledChannelsAsset = 'assets/channels.json';

  Future<String> loadBundledChannels() => rootBundle.loadString(bundledChannelsAsset);

  static const _playlistKey = 'playlist_m3u_v1';
  static const _playlistUrlKey = 'playlist_url_v1';
  static const _channelKey = 'last_channel_url_v1';
  static const _favoritesKey = 'favorites_v1';
  static const _maxPlaylistBytes = 5 * 1024 * 1024;

  Future<String?> loadText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playlistKey);
  }

  Future<String?> loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playlistUrlKey);
  }

  Future<String?> loadLastChannelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_channelKey);
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
  }

  Future<void> storePlaylist(String m3u, {String? url}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistKey, m3u);
    if (url == null) {
      await prefs.remove(_playlistUrlKey);
    } else {
      await prefs.setString(_playlistUrlKey, url);
    }
  }

  Future<void> storeLastChannel(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_channelKey, url);
  }

  Future<void> storeFavorites(Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, urls.toList());
  }

  /// Auto-detects a JSON channel catalog or a traditional M3U playlist.
  List<TvChannel> parse(String source, {Uri? baseUri}) {
    final trimmed = source.replaceFirst('\uFEFF', '').trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return const JsonChannelParser().parse(source, baseUri: baseUri);
    }
    return _parser.parse(source, baseUri: baseUri);
  }

  Future<String> fetchPlaylist(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Please enter a full HTTP(S) JSON or M3U playlist URL.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, audio/x-mpegurl, */*');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Server returned HTTP ${response.statusCode}.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 25))) {
        bytes.add(chunk);
        if (bytes.length > _maxPlaylistBytes) {
          throw const FormatException('Channel list exceeds 5 MB safety limit.');
        }
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }
}

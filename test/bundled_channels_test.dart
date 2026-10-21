import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/json_channel_parser.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> bundledAsset() =>
      rootBundle.loadString(PlaylistRepository.bundledChannelsAsset);

  test('offline fallback JSON validates and preserves all distinct streams',
      () async {
    final text = await bundledAsset();
    final raw = jsonDecode(text);
    expect(raw, isA<List<dynamic>>());
    final entries = raw as List<dynamic>;
    expect(entries, isNotEmpty);
    expect(entries.length, lessThanOrEqualTo(JsonChannelParser.maxChannels));

    // Derive the expected count from the file that was actually committed.
    // It may contain 511, 513, or another positive number of valid channels.
    final seen = <String>{};
    final uniqueUrlsInOrder = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      expect(entry, isA<Map<String, dynamic>>(),
          reason: 'Entry ${i + 1} must be a JSON object.');
      final map = entry as Map<String, dynamic>;
      final name = map['name'];
      expect(name, isA<String>(),
          reason: 'Entry ${i + 1} must contain a channel name.');
      expect((name as String).trim(), isNotEmpty);
      final url = map['url'];
      expect(url, isA<String>(),
          reason: 'Entry ${i + 1} must contain a stream URL.');
      final uri = Uri.tryParse((url as String).trim());
      expect(uri, isNotNull,
          reason: 'Entry ${i + 1} contains an invalid stream URL.');
      expect(<String>['http', 'https'].contains(uri!.scheme), isTrue);
      expect(uri.host, isNotEmpty);
      if (seen.add(url.trim())) {
        uniqueUrlsInOrder.add(url.trim());
      }
    }

    final channels = const JsonChannelParser().parse(text);
    expect(channels, hasLength(uniqueUrlsInOrder.length),
        reason: 'Every distinct playable URL in the bundled fallback must '
            'be parsed. Matching URLs are intentionally de-duplicated.');
    expect(channels.map((channel) => channel.url).toList(),
        uniqueUrlsInOrder,
        reason: 'The parser must preserve the input URL order and signed URLs.');
    expect(channels.every((channel) =>
        channel.name.isNotEmpty && channel.group.isNotEmpty), isTrue);
  });

  test('repository parses the same bundled fallback with and without base URI',
      () async {
    final source = await bundledAsset();
    final repository = PlaylistRepository();
    final channels = repository.parse(source);
    final online = repository.parse(source,
        baseUri: Uri.parse(PlaylistRepository.defaultChannelsUrl));

    expect(channels, isNotEmpty);
    expect(online, hasLength(channels.length));
    expect(online.map((channel) => channel.url).toList(),
        channels.map((channel) => channel.url).toList());
    expect(online.every((channel) =>
        !channel.url.contains('/home/runner/work/')), isTrue,
        reason: 'The source provenance path must not be treated as media.');
  });

  test('catalog supports 511 and 513 entries without hard-coded assertions',
      () {
    final repository = PlaylistRepository();
    for (final count in <int>[511, 513]) {
      final data = List<Map<String, String>>.generate(
        count,
        (index) => <String, String>{
          'name': 'Example TV ${index + 1}',
          'group': 'News',
          'url': 'https://example.org/channels/$index/live.m3u8',
        },
      );
      final channels = repository.parse(jsonEncode(data));
      expect(channels, hasLength(count));
    }
  });
}

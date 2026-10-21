import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/json_channel_parser.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> bundledAsset() =>
      rootBundle.loadString(PlaylistRepository.bundledChannelsAsset);

  test('bundled README.json snapshot parses to all 513 TV entries', () async {
    final text = await bundledAsset();
    final raw = jsonDecode(text) as List<dynamic>;
    expect(raw, hasLength(513),
        reason: 'The bundled assets/channels.json must contain the complete '
            '513-entry README.json snapshot, not a truncated replacement.');
    final channels = const JsonChannelParser().parse(text);
    expect(channels, hasLength(raw.length),
        reason: 'The parser must preserve each distinct stream from the '
            'bundled catalog. Check rejected URLs or accidental de-duplication.');
    expect(channels.first.name, 'Ekushey TV');
    expect(channels.first.group, 'Akash Go');
    expect(channels.first.url,
        'http://210.4.72.204/hls-live/livepkgr/_definst_/liveevent/livestream3.m3u8');
    expect(channels.any((e) => e.name == 'Deepto TV'), isTrue);
    expect(channels.any((e) => e.group == 'Sports'), isTrue);
    expect(channels.any((e) => e.group == 'News'), isTrue);
    expect(channels.every((e) => e.url.startsWith('http')), isTrue);
    expect(channels.map((e) => e.url).toList(),
        raw.map((e) => (e as Map<String, dynamic>)['url']).toList(),
        reason: 'Every stream must be kept in the original order.');
  });

  test('repository correctly parses the bundled full JSON source', () async {
    final source = await bundledAsset();
    final repository = PlaylistRepository();
    final channels = repository.parse(source);
    expect(channels, hasLength(513));
    final online = repository.parse(source,
        baseUri: Uri.parse(PlaylistRepository.defaultChannelsUrl));
    expect(online, hasLength(513));
    expect(online.map((channel) => channel.url).toList(),
        channels.map((channel) => channel.url).toList());
    expect(online.every((channel) => !channel.url.contains('/home/runner/work/')),
        isTrue, reason: 'The source provenance path is not a video stream.');
  });
}

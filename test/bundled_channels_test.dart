import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/json_channel_parser.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';

void main() {
  test('bundled README.json snapshot parses to all 513 TV entries', () async {
    final text = await File('assets/channels.json').readAsString();
    final channels = const JsonChannelParser().parse(text);

    expect(channels.length, 513);
    expect(channels.first.name, 'Ekushey TV');
    expect(channels.first.group, 'Akash Go');
    expect(channels.first.url,
        'http://210.4.72.204/hls-live/livepkgr/_definst_/liveevent/livestream3.m3u8');
    expect(channels.any((e) => e.name == 'Deepto TV'), isTrue);
    expect(channels.any((e) => e.group == 'Sports'), isTrue);
    expect(channels.any((e) => e.group == 'News'), isTrue);
    expect(channels.every((e) => e.url.startsWith('http')), isTrue);
  });

  test('repository correctly parses the bundled full JSON source', () async {
    final source = await File('assets/channels.json').readAsString();
    final channels = PlaylistRepository().parse(source);
    expect(channels, hasLength(513));
    final online = PlaylistRepository().parse(source,
        baseUri: Uri.parse(PlaylistRepository.defaultChannelsUrl));
    expect(online, hasLength(513));
    expect(online.first.url, channels.first.url);
    expect(online.first.url, isNot(contains('/home/runner/work/')));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/models/channel.dart';
import 'package:live_tv_remote/services/json_channel_parser.dart';
import 'package:live_tv_remote/services/playback_policy.dart';

void main() {
  test('recent channels: newest first, no duplicates, capped', () {
    var recent = <String>[];
    recent = pushRecentChannel(recent, 'a');
    recent = pushRecentChannel(recent, 'b');
    recent = pushRecentChannel(recent, 'a');
    expect(recent, <String>['a', 'b']);
    for (var i = 0; i < 40; i++) {
      recent = pushRecentChannel(recent, 'c$i');
    }
    expect(recent, hasLength(maxRecentChannels));
    expect(recent.first, 'c39');
  });

  test('recent indices follow recency and skip removed channels', () {
    final keys = <String>['k0', 'k1', 'k2'];
    expect(recentChannelIndices(keys, <String>['k2', 'gone', 'k0']),
        <int>[2, 0]);
  });

  test('BACK exits only on a second press within the window', () {
    final t0 = DateTime(2026, 1, 1, 12);
    expect(shouldExitOnBack(null, t0), isFalse);
    expect(shouldExitOnBack(t0, t0.add(const Duration(milliseconds: 100))),
        isFalse);
    expect(shouldExitOnBack(t0, t0.add(const Duration(seconds: 1))), isTrue);
    expect(shouldExitOnBack(t0, t0.add(const Duration(seconds: 3))), isFalse);
  });

  test('auto retry delays grow and stop after the limit', () {
    expect(autoRetryDelay(0), isNull);
    expect(autoRetryDelay(1), const Duration(seconds: 3));
    expect(autoRetryDelay(3), const Duration(seconds: 15));
    expect(autoRetryDelay(maxAutoRetries + 1), isNull);
  });

  test('failover: backups first, then reconnects, then give up', () {
    const channel = TvChannel(
      name: 'News',
      url: 'https://a.example/1.m3u8',
      backups: <String>['https://b.example/1.m3u8'],
    );
    expect(nextFailoverAction(channel, 0, 0), FailoverAction.nextSource);
    expect(nextFailoverAction(channel, 1, 0), FailoverAction.retrySameChannel);
    expect(nextFailoverAction(channel, 1, maxAutoRetries),
        FailoverAction.giveUp);
    const single = TvChannel(name: 'X', url: 'https://a.example/x.m3u8');
    expect(nextFailoverAction(single, 0, 0), FailoverAction.retrySameChannel);
  });

  test('JSON entries keep extra stream URLs as backups', () {
    const json = '''
    [
      {"name": "One", "group": "News",
       "streams": ["https://a.example/1.m3u8", "https://b.example/1.m3u8",
                   "https://a.example/1.m3u8"]},
      {"name": "Two", "url": "https://a.example/2.m3u8",
       "backup_urls": ["https://c.example/2.m3u8", "not a url"]},
      {"name": "Three", "url": "https://a.example/3.m3u8"}
    ]''';
    final channels = const JsonChannelParser().parse(json);
    expect(channels, hasLength(3));
    expect(channels[0].url, 'https://a.example/1.m3u8');
    expect(channels[0].backups, <String>['https://b.example/1.m3u8']);
    expect(channels[0].sources, hasLength(2));
    expect(channels[1].backups, <String>['https://c.example/2.m3u8']);
    expect(channels[2].backups, isEmpty);
  });
}

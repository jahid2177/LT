import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';
import 'package:live_tv_remote/services/channel_identity.dart';

void main() {
  final repository = PlaylistRepository();
  test('GitHub channels.json is the authoritative channel URL', () {
    expect(PlaylistRepository.defaultChannelsUrl,
        'https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json');
  });

  test('a changed GitHub catalog changes the channel count and links', () {
    const first = '''[
      {"name":"News One","group":"News","url":"https://tv.example/old.m3u8"},
      {"name":"Sport One","group":"Sports","url":"https://tv.example/sport.m3u8"}
    ]''';
    const next = '''[
      {"name":"News One","group":"News","url":"https://tv.example/new.m3u8"},
      {"name":"Music One","group":"Music","url":"https://tv.example/music.m3u8"},
      {"name":"Kids One","group":"Kids","url":"https://tv.example/kids.m3u8"}
    ]''';
    final before = repository.parse(first);
    final after = repository.parse(next);
    expect(before, hasLength(2));
    expect(after, hasLength(3));
    expect(after.any((channel) => channel.name == 'Sport One'), false);
    expect(after.any((channel) => channel.name == 'Kids One'), true);
    final oldKey = stableChannelKey(before, 0);
    final index = channelIndexForKey(after, oldKey);
    expect(index, 0);
    expect(after[index].url, 'https://tv.example/new.m3u8');
  });
}

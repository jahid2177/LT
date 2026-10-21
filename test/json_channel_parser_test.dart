import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/json_channel_parser.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';

void main() {
  const parser = JsonChannelParser();

  test('parses a GitHub-style channels JSON array', () {
    final channels = parser.parse('''
[
  {"name":"Bangla News", "url":"https://tv.example/news.m3u8",
    "category":"News", "logo":"https://tv.example/news.png"},
  {"title":"Sports One", "stream_url":"https://tv.example/sport.m3u8",
    "group":"Sports"}
]
''');
    expect(channels, hasLength(2));
    expect(channels.first.name, 'Bangla News');
    expect(channels.first.group, 'News');
    expect(channels.first.logo, 'https://tv.example/news.png');
    expect(channels[1].name, 'Sports One');
    expect(channels[1].group, 'Sports');
  });

  test('parses nested channels with sources and skips iframe', () {
    final channels = parser.parse('''
{
  "channels": [
    {"id": "news", "name": "News TV", "category": "News", "signals": [
      {"type":"iframe", "url":"https://tv.example/embed"},
      {"type":"m3u8", "url":"https://tv.example/news.m3u8"}
    ]}
  ]
}
''');
    expect(channels, hasLength(1));
    expect(channels.single.epgId, 'news');
    expect(channels.single.url, 'https://tv.example/news.m3u8');
  });

  test('parses categorized maps and relative stream URLs', () {
    final channels = parser.parse('''
{
  "News": [{"name":"My News","stream":"live/news.m3u8"}],
  "Sports": [{"name":"My Sports","sources":[{"url":"https://tv.example/sport.m3u8"}]}]
}
''', baseUri: Uri.parse('https://tv.example/playlists/channels.json'));
    expect(channels, hasLength(2));
    expect(channels.first.group, 'News');
    expect(channels.first.url, 'https://tv.example/playlists/live/news.m3u8');
    expect(channels[1].group, 'Sports');
  });

  test('parses categorized arrays', () {
    final channels = parser.parse('''
{"categories": [{"name":"Music", "channels": [
  {"name":"Radio TV", "url":"https://tv.example/music.m3u8"}
]}]}
''');
    expect(channels.single.group, 'Music');
  });

  test('removes duplicate streams and rejects invalid JSON lists', () {
    final channels = parser.parse('''[
      {"name":"Channel 1", "url":"https://a.example/live.m3u8"},
      {"name":"Channel 2", "url":"https://a.example/live.m3u8"}
    ]''');
    expect(channels, hasLength(1));
    expect(() => parser.parse('{"channels":[{"name":"A"}]}'),
        throwsFormatException);
  });

  test('runner provenance is not a media stream even with an online baseUri', () {
    const source = '''[
      {"name":"News","url":"https://tv.example/news.m3u8?token=abc123",
       "source":"/home/runner/work/project/source.m3u"}
    ]''';
    final channels = parser.parse(source,
        baseUri: Uri.parse('https://raw.githubusercontent.com/example/channels.json'));
    expect(channels, hasLength(1));
    expect(channels.single.url, 'https://tv.example/news.m3u8?token=abc123');
  });

  test('repository auto-detects JSON and M3U', () {
    final repository = PlaylistRepository();
    final jsonChannels = repository.parse('''
{"channels":[{"name":"TV", "url":"https://a.example/live.m3u8"}]}
''');
    expect(jsonChannels, hasLength(1));
    final m3uChannels = repository.parse('''#EXTM3U
#EXTINF:-1,TV
https://a.example/live.m3u8
''');
    expect(m3uChannels, hasLength(1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/m3u_parser.dart';

void main() {
  test('M3U parser handles groups, names, duplicates and relative URLs', () {
    const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="news-1" group-title="News",Daily News
live/news.m3u8
#EXTINF:-1 group-title="Sports",Sport HD
https://stream.example/sport.m3u8
#EXTINF:-1 group-title="Sports",Duplicate Sport
https://stream.example/sport.m3u8
''';
    final channels = const M3uParser().parse(m3u,
        baseUri: Uri.parse('https://example.com/tv/playlist.m3u'));
    expect(channels, hasLength(2));
    expect(channels[0].name, 'Daily News');
    expect(channels[0].group, 'News');
    expect(channels[0].epgId, 'news-1');
    expect(channels[0].url, 'https://example.com/tv/live/news.m3u8');
    expect(channels[1].group, 'Sports');
  });

  test('rejects unsupported playlists and HLS master file', () {
    expect(() => const M3uParser().parse('garbage'), throwsFormatException);
    expect(() => const M3uParser().parse('''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000
somefile.m3u8'''), throwsFormatException);
  });

  test('channel changing wraps in both directions', () {
    expect(wrapChannelIndex(0, -1, 3), 2);
    expect(wrapChannelIndex(2, 1, 3), 0);
    expect(wrapChannelIndex(0, 1, 0), -1);
    expect(wrapChannelIndex(1, 2, 4), 3);
  });
}

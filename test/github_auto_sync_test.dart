import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/models/channel.dart';
import 'package:live_tv_remote/services/channel_identity.dart';
import 'package:live_tv_remote/services/playlist_repository.dart';

void main() {
  test('stream URL changes do not change channel identity', () {
    final old = <TvChannel>[
      const TvChannel(name: 'News One', group: 'News', url: 'https://x.example/old.m3u8'),
      const TvChannel(name: 'Sport', group: 'Sports', url: 'https://x.example/sport.m3u8'),
    ];
    final fresh = <TvChannel>[
      const TvChannel(name: 'Sport', group: 'Sports', url: 'https://x.example/sport.m3u8'),
      const TvChannel(name: 'News One', group: 'News', url: 'https://x.example/new.m3u8'),
    ];
    final oldKey = stableChannelKey(old, 0);
    expect(channelIndexForKey(fresh, oldKey), 1);
    expect(fresh[channelIndexForKey(fresh, oldKey)].url, endsWith('/new.m3u8'));
  });

  test('duplicate channel names remain independently identifiable', () {
    const one = TvChannel(name: 'Sports', group: 'TV', url: 'https://x.example/a.m3u8');
    const two = TvChannel(name: 'Sports', group: 'TV', url: 'https://x.example/b.m3u8');
    const oneNew = TvChannel(name: 'Sports', group: 'TV', url: 'https://x.example/a2.m3u8');
    const twoNew = TvChannel(name: 'Sports', group: 'TV', url: 'https://x.example/b2.m3u8');
    final keys = [stableChannelKey([one, two], 0), stableChannelKey([one, two], 1)];
    expect(keys[0], isNot(keys[1]));
    expect(channelIndexForKey([oneNew, twoNew], keys[0]), 0);
    expect(channelIndexForKey([oneNew, twoNew], keys[1]), 1);
  });

  test('EPG ID is preferred over rename and stream URL', () {
    const old = TvChannel(name: 'Old', group: 'News', epgId: 'channel-1', url: 'https://x.example/1.m3u8');
    const updated = TvChannel(name: 'New Name', group: 'News', epgId: 'channel-1', url: 'https://x.example/2.m3u8');
    expect(stableChannelKey([old], 0), stableChannelKey([updated], 0));
  });

  test('HTTP etag revalidation returns 304 and refreshed JSON 200', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestedWithEtag = false;
    server.listen((request) async {
      final etag = request.headers.value(HttpHeaders.ifNoneMatchHeader);
      if (etag == '"v1"') {
        requestedWithEtag = true;
        request.response.statusCode = HttpStatus.notModified;
      } else {
        request.response.headers.set(HttpHeaders.etagHeader, '"v1"');
        request.response.write('[{"name":"Test TV","url":"https://example.org/stream.m3u8"}]');
      }
      await request.response.close();
    });
    addTearDown(() async => server.close(force: true));
    final repo = PlaylistRepository();
    final url = 'http://127.0.0.1:${server.port}/channels.json';
    final first = await repo.fetchPlaylistWithMetadata(url);
    expect(first.notModified, false);
    expect(first.etag, '"v1"');
    expect(repo.parse(first.text!).single.name, 'Test TV');
    final unchanged = await repo.fetchPlaylistWithMetadata(url, etag: first.etag);
    expect(requestedWithEtag, true);
    expect(unchanged.notModified, true);
    expect(unchanged.text, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/models/channel.dart';
import 'package:live_tv_remote/services/channel_search.dart';

void main() {
  const items = <TvChannel>[
    TvChannel(name: 'Ekushey TV', url: 'https://example.com/a.m3u8', group: 'Bangla'),
    TvChannel(name: 'Deepto TV', url: 'https://example.com/b.m3u8', group: 'Bangla'),
    TvChannel(name: 'Sports First', url: 'https://example.com/c.m3u8', group: 'Sports'),
    TvChannel(name: 'বাংলা সংবাদ', url: 'https://example.com/d.m3u8', group: 'News'),
  ];

  test('search is case-insensitive and matches name and group', () {
    expect(searchChannelIndices(items, query: 'dEePtO'), [1]);
    expect(searchChannelIndices(items, query: 'SPORTS'), [2]);
    expect(searchChannelIndices(items, query: 'bangla'), [0, 1]);
  });
  test('search supports channel numbers and Bengali text', () {
    expect(searchChannelIndices(items, query: '3'), [2]);
    expect(searchChannelIndices(items, query: 'বাংলা'), [3]);
  });
  test('multiple words must match; favorite filters combine with search', () {
    expect(searchChannelIndices(items, query: 'tv bangla'), [0, 1]);
    expect(searchChannelIndices(items, query: 'tv bangla', allowedIndices: {1, 2}), [1]);
    expect(searchChannelIndices(items, query: 'not here'), isEmpty);
  });
  test('clearing search returns full channel list in original order', () {
    expect(searchChannelIndices(items, query: '   '), [0, 1, 2, 3]);
  });
}

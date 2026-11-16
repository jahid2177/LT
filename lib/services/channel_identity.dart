import '../models/channel.dart';

/// Stable logical identity independent of a channel's (possibly expiring)
/// stream URL. When the feed has no EPG ID, use group + name + occurrence.
/// Duplicate entries retain their position among identically named channels.
String stableChannelKey(List<TvChannel> channels, int index) {
  final channel = channels[index];
  final epg = channel.epgId.trim().toLowerCase();
  if (epg.isNotEmpty) {
    final ordinal = channels.take(index + 1)
        .where((e) => e.epgId.trim().toLowerCase() == epg).length;
    return 'epg:$epg#$ordinal';
  }
  final group = channel.group.trim().toLowerCase();
  final name = channel.name.trim().toLowerCase();
  final ordinal = channels.take(index + 1).where((e) =>
      e.epgId.trim().isEmpty &&
      e.group.trim().toLowerCase() == group &&
      e.name.trim().toLowerCase() == name).length;
  return 'name:$group/$name#$ordinal';
}

/// All stable keys in one O(n) pass; `result[i] == stableChannelKey(channels, i)`.
/// Use this for whole-list work (favorites filter, lookups) on slow TV CPUs.
List<String> stableChannelKeys(List<TvChannel> channels) {
  final seen = <String, int>{};
  final keys = <String>[];
  for (final channel in channels) {
    final epg = channel.epgId.trim().toLowerCase();
    final base = epg.isNotEmpty
        ? 'epg:$epg'
        : 'name:${channel.group.trim().toLowerCase()}/'
            '${channel.name.trim().toLowerCase()}';
    final ordinal = (seen[base] ?? 0) + 1;
    seen[base] = ordinal;
    keys.add('$base#$ordinal');
  }
  return keys;
}

int channelIndexForKey(List<TvChannel> channels, String? key) {
  if (key == null || key.isEmpty) return -1;
  return stableChannelKeys(channels).indexOf(key);
}

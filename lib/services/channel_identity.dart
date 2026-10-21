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

int channelIndexForKey(List<TvChannel> channels, String? key) {
  if (key == null || key.isEmpty) return -1;
  for (var i = 0; i < channels.length; i++) {
    if (stableChannelKey(channels, i) == key) return i;
  }
  return -1;
}

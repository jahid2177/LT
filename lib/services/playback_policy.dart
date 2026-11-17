import '../models/channel.dart';

/// Pure helpers for the TV player. Kept free of Flutter so they are unit
/// tested without a device.

/// Recently watched channel keys, newest first, without duplicates.
const maxRecentChannels = 20;

List<String> pushRecentChannel(List<String> recent, String key,
    {int max = maxRecentChannels}) {
  final next = <String>[key, ...recent.where((e) => e != key)];
  return next.length > max ? next.sublist(0, max) : next;
}

/// Indices of [channelKeys] that appear in [recent], newest first.
/// Keys that no longer exist in the catalogue are skipped.
List<int> recentChannelIndices(List<String> channelKeys, List<String> recent) {
  final positions = <String, int>{};
  for (var i = 0; i < channelKeys.length; i++) {
    positions.putIfAbsent(channelKeys[i], () => i);
  }
  return <int>[
    for (final key in recent)
      if (positions.containsKey(key)) positions[key]!,
  ];
}

/// BACK on the playing screen: the first press shows "press BACK again to
/// exit", a second press within [window] (and not an accidental double event
/// closer than [minGap]) exits.
bool shouldExitOnBack(DateTime? lastPress, DateTime now,
    {Duration window = const Duration(seconds: 2),
    Duration minGap = const Duration(milliseconds: 250)}) {
  if (lastPress == null) return false;
  final gap = now.difference(lastPress);
  return gap >= minGap && gap <= window;
}

/// Seconds to wait before automatic reconnect attempt number [attempt]
/// (1-based). Null when no more attempts are allowed.
const maxAutoRetries = 3;

Duration? autoRetryDelay(int attempt) {
  if (attempt < 1 || attempt > maxAutoRetries) return null;
  const seconds = <int>[3, 8, 15];
  return Duration(seconds: seconds[attempt - 1]);
}

/// What to do after the current stream of [channel] failed while the
/// zero-based source [sourceIndex] was in use.
enum FailoverAction { nextSource, retrySameChannel, giveUp }

FailoverAction nextFailoverAction(
    TvChannel channel, int sourceIndex, int autoRetriesUsed) {
  if (sourceIndex + 1 < channel.sources.length) {
    return FailoverAction.nextSource;
  }
  if (autoRetriesUsed < maxAutoRetries) return FailoverAction.retrySameChannel;
  return FailoverAction.giveUp;
}

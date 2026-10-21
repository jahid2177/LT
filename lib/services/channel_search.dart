import '../models/channel.dart';

/// Filters the already downloaded channel catalogue. Search never triggers
/// network requests or changes the GitHub playlist / original channel order.
List<int> searchChannelIndices(
  List<TvChannel> channels, {
  String query = '',
  Set<int>? allowedIndices,
}) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty).toList();
  final matches = <int>[];
  for (var index = 0; index < channels.length; index++) {
    if (allowedIndices != null && !allowedIndices.contains(index)) continue;
    if (words.isEmpty) {
      matches.add(index);
      continue;
    }
    final channel = channels[index];
    final searchable = '${index + 1} ${channel.name} ${channel.group}'.toLowerCase();
    if (words.every(searchable.contains)) matches.add(index);
  }
  return matches;
}

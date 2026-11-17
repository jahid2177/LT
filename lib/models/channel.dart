import 'package:flutter/foundation.dart';

@immutable
class TvChannel {
  const TvChannel({
    required this.name,
    required this.url,
    this.group = 'Other',
    this.logo = '',
    this.epgId = '',
    this.backups = const <String>[],
  });

  final String name;
  final String url;
  final String group;
  final String logo;
  final String epgId;

  /// Alternative stream URLs for the same channel. The player tries them in
  /// order when [url] does not start or breaks.
  final List<String> backups;

  /// [url] followed by every backup, without duplicates.
  List<String> get sources => <String>[url, ...backups];
}

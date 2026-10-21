import 'package:flutter/foundation.dart';

@immutable
class TvChannel {
  const TvChannel({
    required this.name,
    required this.url,
    this.group = 'Other',
    this.logo = '',
    this.epgId = '',
  });

  final String name;
  final String url;
  final String group;
  final String logo;
  final String epgId;
}

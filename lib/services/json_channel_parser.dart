import 'dart:convert';

import '../models/channel.dart';

/// Parses network channel catalogs where channel entries contain a stream URL.
/// Supports arrays, {"channels": [...]}, {"data": [...]}, named groups and
/// entries with nested "streams"/"sources". It does not circumvent DRM or
/// convert YouTube/iframe webpages into playable media streams.
class JsonChannelParser {
  const JsonChannelParser();

  static const maxChannels = 5000;
  static const _streamKeys = <String>[
    'stream_url', 'streamUrl', 'streamURL', 'stream_link',
    'playback_url', 'playbackUrl', 'playUrl', 'play_url', 'video_url', 'videoUrl',
    // Prefer explicit playable URLs over provenance metadata such as
    // `source: /home/runner/work/.../Movies.m3u` in the supplied README.json.
    // An absolute local provenance path must never be resolved against a
    // GitHub JSON baseUri and mistaken for an HTTP stream.
    'm3u8', 'hls', 'stream', 'streams', 'sources',
    'signals', 'links', 'urls', 'qualities', 'playback', 'url', 'link', 'src', 'file',
    'source',
  ];
  static const _collections = <String>{
    'channels', 'data', 'items', 'results', 'list', 'stations',
    'tv_channels', 'tvChannels', 'categories', 'groups', 'sections',
    'content', 'entries', 'channel',
  };

  List<TvChannel> parse(String source, {Uri? baseUri}) {
    final decoded = jsonDecode(source.replaceFirst('\uFEFF', '').trim());
    final result = <TvChannel>[];
    final seen = <String>{};

    void visit(dynamic node, String group, String fallbackName, int depth) {
      if (depth > 12 || result.length >= maxChannels) return;
      if (node is List) {
        for (final item in node) {
          visit(item, group, fallbackName, depth + 1);
          if (result.length >= maxChannels) break;
        }
        return;
      }
      if (node is! Map) return;
      final value = node.map((key, value) => MapEntry('$key', value));
      final entryName = _firstText(value, const <String>[
            'name', 'title', 'channel_name', 'channelName',
            'display_name', 'displayName', 'label', 'channel',
          ]) ?? fallbackName;
      final entryGroup = _firstText(value, const <String>[
            'group', 'category', 'group-title', 'group_name',
            'category_name', 'genre',
          ]) ?? group;
      final effectiveGroup = entryGroup.trim().isEmpty ? 'Other' : entryGroup;
      final stream = _findStream(value, baseUri, 0);
      if (stream != null && entryName.trim().isNotEmpty) {
        if (seen.add(stream)) {
          result.add(TvChannel(
            name: entryName.trim(),
            url: stream,
            group: effectiveGroup,
            logo: _firstText(value, const <String>[
                  'logo', 'logo_url', 'logoUrl', 'image', 'icon',
                  'thumbnail', 'tvg-logo',
                ]) ?? '',
            epgId: _firstText(value, const <String>[
                  'tvg_id', 'tvg-id', 'epg_id', 'epgId', 'id',
                ]) ?? '',
          ));
        }
        return;
      }

      final groupName = _firstText(value, const <String>['name', 'title']);
      final childGroup = (value.containsKey('channels') ||
                  value.containsKey('items') || value.containsKey('stations')) &&
              groupName != null && entryGroup == group
          ? groupName
          : effectiveGroup;
      // Named collection keys such as {"News": [{...}], "Sports": [{...}]}
      for (final item in value.entries) {
        if (result.length >= maxChannels) break;
        final child = item.value;
        // Also handle compact {"Channel Name": "https://.../live.m3u8"}
        // dictionaries without accidentally treating arbitrary website links
        // or image metadata as media streams.
        if (child is String &&
            !const <String>{'url', 'logo', 'image', 'website', 'id',
              'name', 'title', 'version', 'generated', 'updated_at'}
                .contains(item.key)) {
          final url = _validateUrl(child, baseUri);
          if (url != null &&
              RegExp(r'\.(m3u8|mpd|mp4|ts)(\?|$)', caseSensitive: false)
                  .hasMatch(url) && seen.add(url)) {
            result.add(TvChannel(name: item.key, url: url, group: group));
          }
        }
        if (child is! Map && child is! List) continue;
        if (_collections.contains(item.key)) {
          visit(child, childGroup, '', depth + 1);
        } else if (child is List && child.isNotEmpty &&
            child.every((element) => element is Map)) {
          visit(child, item.key, '', depth + 1);
        } else if (child is Map &&
            !const <String>{'metadata', 'meta', 'pagination', 'config'}
                .contains(item.key)) {
          visit(child, item.key, '', depth + 1);
        }
      }
    }

    visit(decoded, 'Other', '', 0);
    if (result.isEmpty) {
      throw const FormatException(
        'JSON downloaded, but no playable HTTP/HTTPS stream URLs were found. '
        'The feed may use a different schema, non-stream webpages, or DRM.',
      );
    }
    return result;
  }

  String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final item = map[key];
      if (item is String && item.trim().isNotEmpty) {
        return item.trim();
      }
    }
    return null;
  }

  String? _findStream(Map<String, dynamic> entry, Uri? baseUri, int depth) {
    if (depth > 6) {
      return null;
    }
    final type = _firstText(entry, const <String>['type', 'format', 'source_type'])
        ?.toLowerCase();
    if (type != null &&
        (type.contains('iframe') || type.contains('youtube') ||
         type.contains('embed') || type.contains('drm'))) {
      return null;
    }

    for (final key in _streamKeys) {
      final value = entry[key];
      if (value is String) {
        final url = _validateUrl(value, baseUri);
        if (url != null) {
          return url;
        }
      } else if (value is Map) {
        final nested = _findStream(
          value.map((key, value) => MapEntry('$key', value)),
          baseUri, depth + 1,
        );
        if (nested != null) {
          return nested;
        }
      } else if (value is List) {
        for (final nested in value) {
          if (nested is String) {
            final url = _validateUrl(nested, baseUri);
            if (url != null) {
              return url;
            }
          } else if (nested is Map) {
            final url = _findStream(
              nested.map((key, value) => MapEntry('$key', value)),
              baseUri, depth + 1,
            );
            if (url != null) {
              return url;
            }
          }
        }
      }
    }
    return null;
  }

  String? _validateUrl(String raw, Uri? baseUri) {
    final value = raw.trim();
    if (value.isEmpty || value.startsWith('javascript:') ||
        value.startsWith('data:')) {
      return null;
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      return null;
    }
    final resolved = !parsed.hasScheme && baseUri != null
        ? baseUri.resolveUri(parsed)
        : parsed;
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty) {
      return null;
    }
    return resolved.toString();
  }
}

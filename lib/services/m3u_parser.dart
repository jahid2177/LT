import '../models/channel.dart';

/// Handles IPTV-style M3U (EXTINF followed by a playable HTTP(S) URL).
/// HLS media manifests containing #EXT-X- tags are intentionally not channel lists.
class M3uParser {
  const M3uParser();

  static final RegExp _attribute = RegExp(r'([\w-]+)\s*=\s*"([^"]*)"');
  static const int maxChannels = 2000;

  List<TvChannel> parse(String source, {Uri? baseUri}) {
    final content = source.replaceFirst('\uFEFF', '').trim();
    if (!content.startsWith('#EXTM3U')) {
      throw const FormatException('Not an M3U playlist (#EXTM3U is missing).');
    }
    if (content.contains('#EXT-X-')) {
      throw const FormatException(
        'This looks like an HLS stream, not a TV channel playlist. '
        'Add the stream inside an M3U #EXTINF entry.',
      );
    }

    final channels = <TvChannel>[];
    final seen = <String>{};
    String? pendingName;
    String pendingGroup = 'Other';
    String pendingLogo = '';
    String pendingId = '';

    for (final untrimmed in content.split(RegExp(r'\r?\n'))) {
      final line = untrimmed.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma = _lastUnquotedComma(line);
        final heading = comma == -1 ? line : line.substring(0, comma);
        final display = comma == -1 ? '' : line.substring(comma + 1).trim();
        final attributes = <String, String>{};
        for (final match in _attribute.allMatches(heading)) {
          attributes[match.group(1)!.toLowerCase()] = match.group(2)!;
        }
        pendingName = display.isEmpty ? 'Unnamed channel' : display;
        pendingGroup = attributes['group-title']?.trim().isNotEmpty == true
            ? attributes['group-title']!.trim()
            : 'Other';
        pendingLogo = attributes['tvg-logo'] ?? '';
        pendingId = attributes['tvg-id'] ?? '';
        continue;
      }
      if (line.startsWith('#')) continue;
      if (pendingName == null) continue; // ignore unlabelled random URLs
      Uri? uri = Uri.tryParse(line);
      if (uri == null) {
        pendingName = null;
        continue;
      }
      if (!uri.hasScheme && baseUri != null) uri = baseUri.resolveUri(uri);
      if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
        pendingName = null;
        continue;
      }
      final url = uri.toString();
      if (seen.add(url)) {
        channels.add(TvChannel(
          name: pendingName,
          url: url,
          group: pendingGroup,
          logo: pendingLogo,
          epgId: pendingId,
        ));
      }
      pendingName = null;
      if (channels.length == maxChannels) break;
    }
    if (channels.isEmpty) {
      throw const FormatException('No usable HTTP/HTTPS channels found in the playlist.');
    }
    return channels;
  }

  int _lastUnquotedComma(String s) {
    var quote = false;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '"') quote = !quote;
      if (s[i] == ',' && !quote) return i;
    }
    return -1;
  }
}

int wrapChannelIndex(int current, int delta, int channelCount) {
  if (channelCount <= 0) return -1;
  return (current + delta) % channelCount < 0
      ? (current + delta) % channelCount + channelCount
      : (current + delta) % channelCount;
}

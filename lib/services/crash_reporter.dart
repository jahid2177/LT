import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Non-blocking on-device crash breadcrumbs; never uploads reports anywhere.
class CrashReporter {
  CrashReporter._();
  static const _channel = MethodChannel('livetv_remote/crash_finder');

  static void stage(String message) {
    unawaited(_send('breadcrumb', <String, String>{'message': message}));
  }

  static void error(String source, Object problem, [StackTrace? stack]) {
    unawaited(_send('reportError', <String, String>{
      'source': source,
      'message': '$problem',
      'stack': '${stack ?? ''}',
    }));
  }

  static void firstFrame() => unawaited(_send('firstFrame', null));

  static Future<void> openFinder() => _send('showCrashFinder', null);

  static Future<void> _send(String method, Map<String, String>? payload) async {
    try {
      await _channel.invokeMethod<void>(method, payload);
    } on MissingPluginException {
      // Flutter unit tests and non-Android runners do not have the native host.
    } on PlatformException catch (exception) {
      debugPrint('Crash Finder unavailable: ${exception.code}');
    } catch (_) {
      // A crash recorder must not interrupt the normal app lifecycle.
    }
  }
}

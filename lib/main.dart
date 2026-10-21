import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/live_tv_screen.dart';
import 'services/crash_reporter.dart';

void main() {
  // Bind inside the same zone used to run the app, avoiding zone mismatch.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      CrashReporter.error('FlutterError', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      CrashReporter.error('Uncaught platform/Dart error', error, stack);
      return true; // We recorded the error; do not terminate for Dart exceptions.
    };
    CrashReporter.stage('Dart main reached');
    runApp(const LiveTvApp());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CrashReporter.firstFrame();
      unawaited(_configureImmersiveMode());
    });
  }, (Object error, StackTrace stack) {
    CrashReporter.error('Uncaught zone error', error, stack);
  });
}

Future<void> _configureImmersiveMode() async {
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (error, stack) {
    CrashReporter.error('Optional immersive TV setup', error, stack);
  }
}

class LiveTvApp extends StatelessWidget {
  const LiveTvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Live TV Remote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF060914),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C5CFF),
            brightness: Brightness.dark,
          ),
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        home: const LiveTvScreen(),
      );
}

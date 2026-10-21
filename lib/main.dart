import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/live_tv_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A TV can reject a SystemChrome request during engine initialization.
  // Never hold back the first Flutter frame on a platform-channel call.
  runApp(const LiveTvApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_configureImmersiveMode());
  });
}

Future<void> _configureImmersiveMode() async {
  try {
    // Landscape is already declared in AndroidManifest.xml.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (error) {
    debugPrint('Optional TV immersive mode was unavailable: $error');
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

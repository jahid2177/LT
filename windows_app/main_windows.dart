// Windows (x64) entry point for Live TV Remote.
//
// Build:  flutter build windows --release -t windows_app/main_windows.dart
//
// The Android app is unchanged. This file only adds what Windows needs:
//  * video playback through libmpv (package:video_player_media_kit), because
//    the official video_player plugin has no Windows implementation;
//  * Windows replacements for the Android-only native channels:
//      - "Keep Screen Awake"  -> SetThreadExecutionState (kernel32)
//      - Crash Finder         -> %LOCALAPPDATA%\LiveTvRemote\crash_log.txt
//      - BACK twice to exit   -> closes the window
//  * keyboard extras: F11 / Alt+Enter = full screen,
//    Page Up / Page Down = channel + / channel -.
//
// The packages used here are added by .github/workflows/windows-exe.yml
// (`flutter pub add ...`), so this folder is excluded from Android analysis.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:live_tv_remote/main.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

void main() {
  runLiveTvApp(
    ensureBinding: _WindowsBinding.ensureInitialized,
    beforeRunApp: () {
      VideoPlayerMediaKit.ensureInitialized(windows: true);
      HardwareKeyboard.instance.addHandler(_handleWindowsKeys);
    },
  );
}

// ---------------------------------------------------------------------------
// Binding: routes the Android-only method channels to Windows code.
// ---------------------------------------------------------------------------

class _WindowsBinding extends WidgetsFlutterBinding {
  static bool _created = false;

  static WidgetsBinding ensureInitialized() {
    if (!_created) {
      _created = true;
      _WindowsBinding();
    }
    return WidgetsBinding.instance;
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      _WindowsMessenger(super.createBinaryMessenger());
}

class _WindowsMessenger extends BinaryMessenger {
  _WindowsMessenger(this._inner);

  final BinaryMessenger _inner;
  static const _standard = StandardMethodCodec();
  static const _json = JSONMethodCodec();

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    try {
      switch (channel) {
        case 'livetv_remote/screen_awake':
          final call = _standard.decodeMethodCall(message);
          if (call.method == 'setKeepAwake') {
            _WinApi.keepAwake(call.arguments == true);
          }
          return Future.value(_standard.encodeSuccessEnvelope(null));
        case 'livetv_remote/crash_finder':
          final call = _standard.decodeMethodCall(message);
          _CrashLog.handle(call.method, call.arguments);
          return Future.value(_standard.encodeSuccessEnvelope(null));
        case 'flutter/platform':
          // Android closes the app with SystemNavigator.pop (BACK twice);
          // the Windows engine ignores that, so close the window instead.
          final call = _json.decodeMethodCall(message);
          if (call.method == 'SystemNavigator.pop') {
            _WinApi.keepAwake(false);
            unawaited(ServicesBinding.instance
                .exitApplication(ui.AppExitType.required));
            return Future.value(_json.encodeSuccessEnvelope(null));
          }
      }
    } catch (_) {
      // Fall through to the engine for anything we could not decode.
    }
    return _inner.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _inner.setMessageHandler(channel, handler);

  // Forward-compatible with framework versions that still declare the old
  // deprecated BinaryMessenger.handlePlatformMessage member.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Keyboard extras.
// ---------------------------------------------------------------------------

bool _handleWindowsKeys(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final key = event.logicalKey;
  final alt = HardwareKeyboard.instance.isAltPressed;
  if (key == LogicalKeyboardKey.f11 ||
      (alt && (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter))) {
    _WinApi.toggleFullScreen();
    return true;
  }
  if (key == LogicalKeyboardKey.pageUp ||
      key == LogicalKeyboardKey.channelUp) {
    _sendRemoteKey('channelUp');
    return true;
  }
  if (key == LogicalKeyboardKey.pageDown ||
      key == LogicalKeyboardKey.channelDown) {
    _sendRemoteKey('channelDown');
    return true;
  }
  return false;
}

/// Delivers a key exactly like the Android native remote bridge does.
void _sendRemoteKey(String name) {
  ui.channelBuffers.push(
    'livetv_remote/keys',
    const StandardMethodCodec()
        .encodeMethodCall(MethodCall('onRemoteKey', name)),
    (ByteData? _) {},
  );
}

// ---------------------------------------------------------------------------
// Crash log file (replaces the Android Crash Finder screen).
// ---------------------------------------------------------------------------

class _CrashLog {
  static File? _file;

  static File? get file {
    if (_file != null) return _file;
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) return null;
    final dir = Directory('$base\\LiveTvRemote');
    try {
      dir.createSync(recursive: true);
    } catch (_) {
      return null;
    }
    return _file = File('${dir.path}\\crash_log.txt');
  }

  static void handle(String method, Object? arguments) {
    final f = file;
    if (f == null) return;
    try {
      if (method == 'reportError' && arguments is Map) {
        if (f.existsSync() && f.lengthSync() > 512 * 1024) {
          f.writeAsStringSync(''); // keep the log small
        }
        f.writeAsStringSync(
          '[${DateTime.now().toIso8601String()}] ${arguments['source']}\n'
          '${arguments['message']}\n${arguments['stack']}\n\n',
          mode: FileMode.append,
        );
      } else if (method == 'showCrashFinder') {
        if (!f.existsSync()) f.writeAsStringSync('No errors recorded.\n');
        unawaited(Process.start('notepad.exe', <String>[f.path]));
      }
    } catch (_) {
      // Logging must never disturb playback.
    }
  }
}

// ---------------------------------------------------------------------------
// Win32 calls through dart:ffi.
// ---------------------------------------------------------------------------

class _WinApi {
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final _user32 = DynamicLibrary.open('user32.dll');

  static final _setThreadExecutionState = _kernel32.lookupFunction<
      Uint32 Function(Uint32), int Function(int)>('SetThreadExecutionState');

  static final _getForegroundWindow = _user32
      .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
  static final _getWindowLongPtr = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32), int Function(int, int)>('GetWindowLongPtrW');
  static final _setWindowLongPtr = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32, IntPtr),
      int Function(int, int, int)>('SetWindowLongPtrW');
  static final _setWindowPos = _user32.lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)>('SetWindowPos');
  static final _showWindow = _user32.lookupFunction<
      Int32 Function(IntPtr, Int32), int Function(int, int)>('ShowWindow');
  static final _isZoomed = _user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsZoomed');
  static final _monitorFromWindow = _user32.lookupFunction<
      IntPtr Function(IntPtr, Uint32), int Function(int, int)>('MonitorFromWindow');
  static final _getMonitorInfo = _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)>('GetMonitorInfoW');

  static const _esContinuous = 0x80000000;
  static const _esSystemRequired = 0x00000001;
  static const _esDisplayRequired = 0x00000002;

  static const _gwlStyle = -16;
  static const _wsOverlappedWindow = 0x00CF0000;
  static const _swpNoSize = 0x0001;
  static const _swpNoMove = 0x0002;
  static const _swpNoZOrder = 0x0004;
  static const _swpFrameChanged = 0x0020;
  static const _swpNoOwnerZOrder = 0x0200;
  static const _swRestore = 9;
  static const _swMaximize = 3;

  /// Same effect as Android FLAG_KEEP_SCREEN_ON while a channel plays.
  static void keepAwake(bool enabled) {
    try {
      _setThreadExecutionState(enabled
          ? _esContinuous | _esSystemRequired | _esDisplayRequired
          : _esContinuous);
    } catch (_) {}
  }

  static int? _fullScreenWindow;
  static int _savedStyle = 0;
  static bool _savedMaximized = true;

  static void toggleFullScreen() {
    try {
      if (_fullScreenWindow != null) {
        final hwnd = _fullScreenWindow!;
        _fullScreenWindow = null;
        _setWindowLongPtr(hwnd, _gwlStyle, _savedStyle);
        _setWindowPos(hwnd, 0, 0, 0, 0, 0,
            _swpNoMove | _swpNoSize | _swpNoZOrder | _swpNoOwnerZOrder |
                _swpFrameChanged);
        _showWindow(hwnd, _savedMaximized ? _swMaximize : _swRestore);
        return;
      }
      final hwnd = _getForegroundWindow();
      if (hwnd == 0) return;
      _savedStyle = _getWindowLongPtr(hwnd, _gwlStyle);
      _savedMaximized = _isZoomed(hwnd) != 0;
      if (_savedMaximized) _showWindow(hwnd, _swRestore);

      // MONITORINFO: cbSize(4) + rcMonitor(16) + rcWork(16) + dwFlags(4).
      final info = calloc<Uint8>(40);
      try {
        info.cast<Uint32>().value = 40;
        final monitor = _monitorFromWindow(hwnd, 2 /* NEAREST */);
        if (_getMonitorInfo(monitor, info) == 0) return;
        final rect = (info + 4).cast<Int32>();
        final left = rect[0], top = rect[1], right = rect[2], bottom = rect[3];
        _setWindowLongPtr(
            hwnd, _gwlStyle, _savedStyle & ~_wsOverlappedWindow);
        _setWindowPos(hwnd, 0, left, top, right - left, bottom - top,
            _swpNoOwnerZOrder | _swpFrameChanged);
        _fullScreenWindow = hwnd;
      } finally {
        calloc.free(info);
      }
    } catch (_) {}
  }
}

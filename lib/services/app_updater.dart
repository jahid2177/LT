import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A newer release published on GitHub than the build that is running.
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
}

/// Self-update from this project's GitHub Releases.
///
/// The release workflow publishes `version.json` + the signed APK. The app
/// compares `versionCode` with its own and hands the APK to Android's
/// PackageInstaller (native side). Android always verifies that the APK is
/// signed with the same key as the installed app before replacing it.
class AppUpdater {
  AppUpdater();

  static const _channel = MethodChannel('livetv_remote/updater');

  /// "latest" always resolves to the newest published (non-draft) release.
  static const manifestUrl =
      'https://github.com/jahid2177/LT/releases/latest/download/version.json';

  /// Only APKs hosted in this repository's releases are ever installed.
  static const allowedApkPrefix =
      'https://github.com/jahid2177/LT/releases/download/';

  static const _maxManifestBytes = 64 * 1024;

  /// Returns the update described by [manifestJson], or null when the manifest
  /// is not newer than [installedVersionCode] or is not trustworthy.
  static AppUpdateInfo? parseManifest(String manifestJson,
      {required int installedVersionCode}) {
    Object? decoded;
    try {
      decoded = jsonDecode(manifestJson.replaceFirst('\uFEFF', '').trim());
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final code = decoded['versionCode'];
    final name = decoded['versionName'];
    final apkUrl = decoded['apkUrl'];
    if (code is! int || name is! String || apkUrl is! String) {
      return null;
    }
    if (code <= installedVersionCode ||
        !apkUrl.toLowerCase().startsWith(allowedApkPrefix.toLowerCase())) {
      return null;
    }
    return AppUpdateInfo(versionCode: code, versionName: name, apkUrl: apkUrl);
  }

  /// Version code of the installed APK, or null outside Android.
  Future<int?> installedVersionCode() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getVersion');
      final code = info?['versionCode'];
      return code is int ? code : null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Checks GitHub for a newer release. Returns null when up to date, when no
  /// release has been published yet, or when running a debug/diagnostic build
  /// (which has a different package name and cannot be replaced by a release).
  Future<AppUpdateInfo?> check() async {
    if (!kReleaseMode) {
      return null;
    }
    final installed = await installedVersionCode();
    if (installed == null) {
      return null;
    }
    final manifest = await _download(manifestUrl);
    if (manifest == null) {
      return null;
    }
    return parseManifest(manifest, installedVersionCode: installed);
  }

  /// Starts downloading [update] and opens Android's install confirmation.
  /// Progress and results arrive through [setEventHandler].
  Future<void> install(AppUpdateInfo update) => _channel.invokeMethod<void>(
        'installUpdate',
        <String, String>{'url': update.apkUrl},
      );

  /// [handler] receives (type, percent, message); type is one of
  /// `progress`, `confirm`, `success` or `failed`.
  void setEventHandler(
      void Function(String type, int? percent, String? message)? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onUpdateEvent') {
        return null;
      }
      final arguments = call.arguments;
      if (arguments is Map) {
        final type = arguments['type'];
        final percent = arguments['percent'];
        final message = arguments['message'];
        handler(
          type is String ? type : 'failed',
          percent is int ? percent : null,
          message is String ? message : null,
        );
      }
      return null;
    });
  }

  Future<String?> _download(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request =
          await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, */*');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        // 404 simply means that no release has been published yet.
        await response.drain<void>();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.add(chunk);
        if (bytes.length > _maxManifestBytes) {
          return null;
        }
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }
}

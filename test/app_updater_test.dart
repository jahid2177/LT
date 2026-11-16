import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/app_updater.dart';

void main() {
  const apk =
      'https://github.com/jahid2177/LT/releases/download/v1.3.0/live-tv-remote.apk';

  test('a newer GitHub release is offered as an update', () {
    final update = AppUpdater.parseManifest(
      '{"versionCode":13,"versionName":"1.3.0","apkUrl":"$apk"}',
      installedVersionCode: 12,
    );
    expect(update, isNotNull);
    expect(update!.versionCode, 13);
    expect(update.versionName, '1.3.0');
    expect(update.apkUrl, apk);
  });

  test('same or older releases are ignored', () {
    for (final installed in <int>[13, 14]) {
      expect(
        AppUpdater.parseManifest(
          '{"versionCode":13,"versionName":"1.3.0","apkUrl":"$apk"}',
          installedVersionCode: installed,
        ),
        isNull,
      );
    }
  });

  test('APK links outside this repository releases are rejected', () {
    expect(
      AppUpdater.parseManifest(
        '{"versionCode":99,"versionName":"9.9.9",'
        '"apkUrl":"https://example.com/live-tv-remote.apk"}',
        installedVersionCode: 12,
      ),
      isNull,
    );
  });

  test('malformed manifests are ignored', () {
    expect(AppUpdater.parseManifest('not json', installedVersionCode: 1), isNull);
    expect(AppUpdater.parseManifest('[]', installedVersionCode: 1), isNull);
    expect(
      AppUpdater.parseManifest('{"versionCode":"13"}', installedVersionCode: 1),
      isNull,
    );
  });
}

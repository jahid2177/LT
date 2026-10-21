import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/screen_awake_policy.dart';

void main() {
  bool awake({
    bool foreground = true,
    bool selected = true,
    bool loading = false,
    bool player = true,
    bool error = false,
  }) => shouldKeepScreenAwake(
        appIsForeground: foreground,
        channelSelected: selected,
        waitingForVideo: loading,
        playerAttached: player,
        hasPlaybackError: error,
      );

  test('active playback keeps the TV display awake', () {
    expect(awake(), isTrue);
  });
  test('initial buffering / switching channels keeps the TV awake', () {
    expect(awake(loading: true, player: false), isTrue);
  });
  test('background, guide without playback, and errors allow sleep', () {
    expect(awake(foreground: false), isFalse);
    expect(awake(selected: false), isFalse);
    expect(awake(loading: false, player: false), isFalse);
    expect(awake(error: true), isFalse);
  });
}

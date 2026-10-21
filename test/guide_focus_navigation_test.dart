import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/guide_focus_navigation.dart';

void main() {
  const firstChannel = GuideSelection(
    section: GuideSection.channels,
    actionIndex: 0,
    channelIndex: 0,
  );

  GuideSelection move(GuideSelection from, GuideDirection key,
      {int channelCount = 513}) =>
      moveGuideSelection(
        selection: from,
        direction: key,
        actionCount: 5,
        channelCount: channelCount,
      );

  test('up at first channel enters the top actions', () {
    final state = move(firstChannel, GuideDirection.up);
    expect(state.section, GuideSection.toolbar);
    expect(state.actionIndex, 0);
    expect(state.closeGuide, false);
  });

  test('up from other channel moves highlight without switching region', () {
    const from = GuideSelection(
      section: GuideSection.channels, actionIndex: 0, channelIndex: 5);
    final state = move(from, GuideDirection.up);
    expect(state.section, GuideSection.channels);
    expect(state.channelIndex, 4);
  });

  test('right from channel list enters actions directly', () {
    final state = move(firstChannel, GuideDirection.right);
    expect(state.section, GuideSection.toolbar);
  });

  test('remote right can reach refresh, debug, settings and close', () {
    var state = move(firstChannel, GuideDirection.up);
    for (var i = 1; i < 5; i++) {
      state = move(state, GuideDirection.right);
      expect(state.actionIndex, i);
      expect(state.section, GuideSection.toolbar);
    }
    // Repeated right stops at the last button.
    expect(move(state, GuideDirection.right).actionIndex, 4);
    // LEFT returns to Settings, Debug and Refresh.
    expect(move(state, GuideDirection.left).actionIndex, 3);
  });

  test('down returns from actions to channel list', () {
    final toolbar = move(firstChannel, GuideDirection.up);
    final state = move(toolbar, GuideDirection.down);
    expect(state.section, GuideSection.channels);
    expect(state.channelIndex, 0);
  });

  test('empty favorites remains on actions, so Show All is reachable', () {
    final state = move(firstChannel, GuideDirection.up, channelCount: 0);
    expect(state.section, GuideSection.toolbar);
    expect(move(state, GuideDirection.down, channelCount: 0).section,
        GuideSection.toolbar);
  });

  test('left from channel list closes drawer, not from toolbar', () {
    expect(move(firstChannel, GuideDirection.left).closeGuide, isTrue);
    final toolbar = move(firstChannel, GuideDirection.up);
    expect(move(toolbar, GuideDirection.left).closeGuide, isFalse);
  });

  test('down at last channel does not wrap to first', () {
    const last = GuideSelection(
        section: GuideSection.channels, actionIndex: 2, channelIndex: 512);
    final state = move(last, GuideDirection.down);
    expect(state.channelIndex, 512);
  });
}

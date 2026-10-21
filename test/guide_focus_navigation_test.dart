import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv_remote/services/guide_focus_navigation.dart';

void main() {
  const firstChannel = GuideSelection(
    section: GuideSection.channels,
    actionIndex: 0,
    channelIndex: 0,
  );

  GuideSelection move(GuideSelection from, GuideDirection key,
      {int channelCount = 12}) =>
      moveGuideSelection(
        selection: from,
        direction: key,
        actionCount: 5,
        channelCount: channelCount,
      );

  test('up at first channel focuses search, then toolbar', () {
    final search = move(firstChannel, GuideDirection.up);
    expect(search.section, GuideSection.search);
    final toolbar = move(search, GuideDirection.up);
    expect(toolbar.section, GuideSection.toolbar);
    expect(toolbar.actionIndex, 0);
  });

  test('up from other channel moves highlight', () {
    const from = GuideSelection(
        section: GuideSection.channels, actionIndex: 0, channelIndex: 5);
    final state = move(from, GuideDirection.up);
    expect(state.section, GuideSection.channels);
    expect(state.channelIndex, 4);
  });

  test('right from channel list enters top actions directly', () {
    expect(move(firstChannel, GuideDirection.right).section,
        GuideSection.toolbar);
  });

  test('left and right reach refresh, debug, settings and close', () {
    var state = move(move(firstChannel, GuideDirection.up), GuideDirection.up);
    for (var i = 1; i < 5; i++) {
      state = move(state, GuideDirection.right);
      expect(state.actionIndex, i);
      expect(state.section, GuideSection.toolbar);
    }
    expect(move(state, GuideDirection.right).actionIndex, 4);
    expect(move(state, GuideDirection.left).actionIndex, 3);
  });

  test('down moves from toolbar to search then channel results', () {
    final toolbar = move(move(firstChannel, GuideDirection.up), GuideDirection.up);
    final search = move(toolbar, GuideDirection.down);
    expect(search.section, GuideSection.search);
    final channel = move(search, GuideDirection.down);
    expect(channel.section, GuideSection.channels);
    expect(channel.channelIndex, 0);
  });

  test('no search results keeps keyboard search row reachable', () {
    final search = move(firstChannel, GuideDirection.up, channelCount: 0);
    expect(search.section, GuideSection.search);
    expect(move(search, GuideDirection.down, channelCount: 0).section,
        GuideSection.search);
    expect(move(search, GuideDirection.up, channelCount: 0).section,
        GuideSection.toolbar);
  });

  test('left from channel list closes drawer, not from toolbar', () {
    expect(move(firstChannel, GuideDirection.left).closeGuide, isTrue);
    final toolbar = move(move(firstChannel, GuideDirection.up), GuideDirection.up);
    expect(move(toolbar, GuideDirection.left).closeGuide, isFalse);
  });

  test('down at last channel does not wrap to first', () {
    const last = GuideSelection(
        section: GuideSection.channels, actionIndex: 2, channelIndex: 11);
    expect(move(last, GuideDirection.down).channelIndex, 11);
  });
}

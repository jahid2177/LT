// Deterministic TV D-pad traversal. Search is an independently selectable row
// between the toolbar and channel results. OK on Search opens the TV keyboard.
enum GuideSection { channels, search, toolbar }
enum GuideDirection { up, down, left, right }

class GuideSelection {
  const GuideSelection({
    required this.section,
    required this.actionIndex,
    required this.channelIndex,
    this.closeGuide = false,
  });

  final GuideSection section;
  final int actionIndex;
  final int channelIndex;
  final bool closeGuide;
}

GuideSelection moveGuideSelection({
  required GuideSelection selection,
  required GuideDirection direction,
  required int actionCount,
  required int channelCount,
}) {
  if (actionCount < 1) throw ArgumentError.value(actionCount, 'actionCount');
  final action = selection.actionIndex.clamp(0, actionCount - 1).toInt();
  final channel = channelCount > 0
      ? selection.channelIndex.clamp(0, channelCount - 1).toInt()
      : 0;

  GuideSelection next(GuideSection section, {int? actionIndex,
      int? channelIndex, bool closeGuide = false}) => GuideSelection(
    section: section,
    actionIndex: actionIndex ?? action,
    channelIndex: channelIndex ?? channel,
    closeGuide: closeGuide,
  );

  return switch ((selection.section, direction)) {
    (GuideSection.toolbar, GuideDirection.left) => next(GuideSection.toolbar,
        actionIndex: (action - 1).clamp(0, actionCount - 1).toInt()),
    (GuideSection.toolbar, GuideDirection.right) => next(GuideSection.toolbar,
        actionIndex: (action + 1).clamp(0, actionCount - 1).toInt()),
    (GuideSection.toolbar, GuideDirection.down) => next(GuideSection.search),
    (GuideSection.toolbar, GuideDirection.up) => next(GuideSection.toolbar),
    (GuideSection.search, GuideDirection.up) ||
    (GuideSection.search, GuideDirection.left) ||
    (GuideSection.search, GuideDirection.right) => next(GuideSection.toolbar),
    (GuideSection.search, GuideDirection.down) => next(channelCount > 0
        ? GuideSection.channels : GuideSection.search),
    (GuideSection.channels, GuideDirection.up) => next(
        channel == 0 || channelCount == 0
            ? GuideSection.search : GuideSection.channels,
        channelIndex: channel > 0 ? channel - 1 : 0),
    (GuideSection.channels, GuideDirection.down) => next(
        channelCount > 0 ? GuideSection.channels : GuideSection.search,
        channelIndex: channelCount > 0
            ? (channel + 1).clamp(0, channelCount - 1).toInt() : 0),
    (GuideSection.channels, GuideDirection.right) => next(GuideSection.toolbar),
    (GuideSection.channels, GuideDirection.left) => next(GuideSection.channels,
        closeGuide: true),
  };
}

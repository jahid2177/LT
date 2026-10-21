// Deterministic channel-guide focus traversal for hardware Android TV D-pads.
// Kept independent of Widgets so its transitions are easy to unit test.
enum GuideSection { channels, toolbar }
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

  if (selection.section == GuideSection.toolbar || channelCount == 0) {
    switch (direction) {
      case GuideDirection.left:
        return GuideSelection(section: GuideSection.toolbar,
            actionIndex: (action - 1).clamp(0, actionCount - 1).toInt(), channelIndex: channel);
      case GuideDirection.right:
        return GuideSelection(section: GuideSection.toolbar,
            actionIndex: (action + 1).clamp(0, actionCount - 1).toInt(), channelIndex: channel);
      case GuideDirection.down:
        return GuideSelection(
            section: channelCount > 0 ? GuideSection.channels : GuideSection.toolbar,
            actionIndex: action, channelIndex: channel);
      case GuideDirection.up:
        return GuideSelection(section: GuideSection.toolbar,
            actionIndex: action, channelIndex: channel);
    }
  }
  switch (direction) {
    case GuideDirection.up:
      if (channel == 0) {
        return GuideSelection(section: GuideSection.toolbar,
            actionIndex: action, channelIndex: channel);
      }
      return GuideSelection(section: GuideSection.channels,
          actionIndex: action, channelIndex: channel - 1);
    case GuideDirection.down:
      return GuideSelection(section: GuideSection.channels,
          actionIndex: action, channelIndex: (channel + 1).clamp(0, channelCount - 1).toInt());
    case GuideDirection.right:
      return GuideSelection(section: GuideSection.toolbar,
          actionIndex: action, channelIndex: channel);
    case GuideDirection.left:
      return GuideSelection(section: GuideSection.channels,
          actionIndex: action, channelIndex: channel, closeGuide: true);
  }
}

/// Use Android's keep-screen-on window flag only while a channel is loading
/// or playing in the foreground. Buffered streams may temporarily report
/// isPlaying=false, so keep it enabled while a player is attached.
bool shouldKeepScreenAwake({
  required bool appIsForeground,
  required bool channelSelected,
  required bool waitingForVideo,
  required bool playerAttached,
  required bool hasPlaybackError,
}) {
  return appIsForeground &&
      channelSelected &&
      !hasPlaybackError &&
      (waitingForVideo || playerAttached);
}

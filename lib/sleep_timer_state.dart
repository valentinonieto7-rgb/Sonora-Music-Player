enum SleepTimerMode { countdown, endOfTrack }

class SleepTimerStatus {
  const SleepTimerStatus.countdown(this.remaining)
    : mode = SleepTimerMode.countdown;

  const SleepTimerStatus.endOfTrack()
    : mode = SleepTimerMode.endOfTrack,
      remaining = null;

  final SleepTimerMode mode;
  final Duration? remaining;

  String get label {
    if (mode == SleepTimerMode.endOfTrack) return 'Al terminar la canción';
    final duration = remaining ?? Duration.zero;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

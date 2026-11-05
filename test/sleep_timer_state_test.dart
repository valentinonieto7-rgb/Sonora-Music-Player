import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/sleep_timer_state.dart';

void main() {
  test('countdown state formats remaining time as minutes and seconds', () {
    const status = SleepTimerStatus.countdown(
      Duration(minutes: 14, seconds: 9),
    );

    expect(status.mode, SleepTimerMode.countdown);
    expect(status.label, '14:09');
  });

  test('end-of-track state has a descriptive label and no countdown', () {
    const status = SleepTimerStatus.endOfTrack();

    expect(status.mode, SleepTimerMode.endOfTrack);
    expect(status.remaining, isNull);
    expect(status.label, 'Al terminar la canción');
  });
}

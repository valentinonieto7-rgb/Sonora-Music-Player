import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/format_duration.dart';

void main() {
  test('formats playback durations as minutes and seconds', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatDuration(Duration.zero), '0:00');
  });
}

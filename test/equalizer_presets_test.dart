import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_flac/equalizer_presets.dart';

void main() {
  test('Flat returns zero gain for every detected band', () {
    final gains = equalizerGainsForPreset(
      preset: 'flat',
      centerFrequencies: [60, 230, 910, 14000],
      minGain: -15,
      maxGain: 15,
    );

    expect(gains, [0, 0, 0, 0]);
  });

  test('presets adapt to detected bands and clamp device gain limits', () {
    final gains = equalizerGainsForPreset(
      preset: 'bass_boost',
      centerFrequencies: [50, 100, 1000, 10000],
      minGain: -3,
      maxGain: 3,
    );

    expect(gains, hasLength(4));
    expect(gains.first, 3);
    expect(gains.last, lessThan(0));
    expect(gains.every((gain) => gain >= -3 && gain <= 3), isTrue);
  });

  test('unknown presets safely map to Flat', () {
    final gains = equalizerGainsForPreset(
      preset: 'missing',
      centerFrequencies: [80, 1200],
      minGain: -10,
      maxGain: 10,
    );

    expect(gains, [0, 0]);
  });
}

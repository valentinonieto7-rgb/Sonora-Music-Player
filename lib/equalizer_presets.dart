import 'dart:math' as math;

const equalizerPresets = {
  'flat': 'Flat',
  'bass_boost': 'Bass Boost',
  'rock': 'Rock',
  'pop': 'Pop',
  'vocal': 'Vocal',
  'custom': 'Personalizado',
};

const _presetCurves = {
  'flat': [
    [31.0, 0.0],
    [16000.0, 0.0],
  ],
  'bass_boost': [
    [31.0, 6.0],
    [62.0, 5.0],
    [125.0, 4.0],
    [250.0, 2.0],
    [500.0, 0.0],
    [1000.0, 0.0],
    [2000.0, -1.0],
    [4000.0, -2.0],
    [8000.0, -2.0],
    [16000.0, -1.0],
  ],
  'rock': [
    [31.0, 4.0],
    [62.0, 3.0],
    [125.0, 2.0],
    [250.0, 0.0],
    [500.0, -1.0],
    [1000.0, 1.0],
    [2000.0, 2.0],
    [4000.0, 3.0],
    [8000.0, 4.0],
    [16000.0, 4.0],
  ],
  'pop': [
    [31.0, -1.0],
    [62.0, 1.0],
    [125.0, 3.0],
    [250.0, 3.0],
    [500.0, 0.0],
    [1000.0, -1.0],
    [2000.0, 0.0],
    [4000.0, 2.0],
    [8000.0, 3.0],
    [16000.0, 2.0],
  ],
  'vocal': [
    [31.0, -3.0],
    [62.0, -2.0],
    [125.0, -1.0],
    [250.0, 0.0],
    [500.0, 1.0],
    [1000.0, 3.0],
    [2000.0, 4.0],
    [4000.0, 3.0],
    [8000.0, 1.0],
    [16000.0, 0.0],
  ],
};

List<double> equalizerGainsForPreset({
  required String preset,
  required List<double> centerFrequencies,
  required double minGain,
  required double maxGain,
}) {
  final curve = _presetCurves[preset] ?? _presetCurves['flat']!;
  return centerFrequencies
      .map((frequency) {
        final gain = _interpolateCurve(curve, frequency);
        return gain.clamp(minGain, maxGain).toDouble();
      })
      .toList(growable: false);
}

double _interpolateCurve(List<List<double>> curve, double frequency) {
  if (frequency <= curve.first[0]) return curve.first[1];
  if (frequency >= curve.last[0]) return curve.last[1];

  for (var index = 0; index < curve.length - 1; index++) {
    final lower = curve[index];
    final upper = curve[index + 1];
    if (frequency > upper[0]) continue;

    final position =
        (math.log(frequency) - math.log(lower[0])) /
        (math.log(upper[0]) - math.log(lower[0]));
    return lower[1] + (upper[1] - lower[1]) * position;
  }
  return 0;
}

class EqualizerState {
  const EqualizerState({
    this.minGain = -15,
    this.maxGain = 15,
    this.centerFrequencies = const [],
    this.gains = const [],
    this.error,
  });

  final double minGain;
  final double maxGain;
  final List<double> centerFrequencies;
  final List<double> gains;
  final String? error;

  bool get isAvailable => centerFrequencies.isNotEmpty;
}

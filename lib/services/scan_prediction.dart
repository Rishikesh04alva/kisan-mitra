class ScanPrediction {
  final String label;
  final double confidence;
  final bool demo;
  final List<MapEntry<String, double>> top;
  final bool uncertain;

  /// Photo was too blurry for a reliable reading.
  final bool blurry;

  /// A user-selected crop constrained which disease classes could win.
  final bool cropFiltered;

  const ScanPrediction({
    required this.label,
    required this.confidence,
    this.demo = false,
    this.top = const [],
    this.uncertain = false,
    this.blurry = false,
    this.cropFiltered = false,
  });
}

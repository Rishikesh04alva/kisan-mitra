class ScanPrediction {
  final String label;
  final double confidence;
  final bool demo;
  final List<MapEntry<String, double>> top;
  final bool uncertain;

  const ScanPrediction({
    required this.label,
    required this.confidence,
    this.demo = false,
    this.top = const [],
    this.uncertain = false,
  });
}

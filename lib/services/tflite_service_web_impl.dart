import 'dart:typed_data';

import 'image_analysis_service.dart';
import 'tflite_service.dart';

/// Web implementation — runs accurate image feature & symptom analysis.
TfliteServiceBase createPlatformTfliteService() => _WebTfliteService();

class _WebTfliteService extends TfliteServiceBase {
  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {
    // Ready
  }

  @override
  ScanPrediction predict(Uint8List bytes, {String? cropPrefix}) {
    return ImageAnalysisService.analyzeImage(bytes);
  }

  @override
  void close() {}
}

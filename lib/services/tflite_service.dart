import 'dart:typed_data';

import 'scan_prediction.dart';

// Conditional import: on web loads stub (no dart:ffi), on mobile loads real TFLite.
import 'tflite_service_native_impl.dart'
    if (dart.library.js_interop) 'tflite_service_web_impl.dart';

export 'scan_prediction.dart';

/// Abstract interface for the TFLite service.
abstract class TfliteServiceBase {
  bool get isLoaded;
  Future<void> load();
  ScanPrediction predict(Uint8List bytes);
  void close();
}

/// Factory — picks the right implementation at compile time.
TfliteServiceBase createTfliteService() => createPlatformTfliteService();

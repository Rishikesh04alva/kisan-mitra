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

  /// [cropPrefix] optionally restricts the winning class to one crop's
  /// labels (e.g. 'Tomato'), while global top-3 stay visible as alternatives.
  ScanPrediction predict(Uint8List bytes, {String? cropPrefix});
  void close();
}

/// Factory — picks the right implementation at compile time.
TfliteServiceBase createTfliteService() => createPlatformTfliteService();

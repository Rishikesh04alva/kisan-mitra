import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/db/app_database.dart';
import '../data/models/models.dart';
import '../services/tflite_service.dart';

enum ScanState { idle, analyzing, done, error }

class ScannerProvider extends ChangeNotifier {
  final AppDatabase db;
  final TfliteService tflite;

  ScanState state = ScanState.idle;
  ScanRecord? lastResult;
  bool lastWasDemo = false;
  String errorKey = 'err_generic';
  List<ScanRecord> history = [];

  ScannerProvider(this.db, this.tflite);

  Future<void> init() async {
    history = await db.getScans(limit: 10);
    notifyListeners();
  }

  bool get isHealthy =>
      lastResult?.healthy ?? false;

  Future<void> analyze(String imagePath, Uint8List bytes) async {
    state = ScanState.analyzing;
    notifyListeners();
    try {
      final prediction = tflite.predict(bytes);
      final record = ScanRecord(
        id: 's_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: imagePath,
        label: prediction.label,
        confidence: prediction.confidence,
        createdAt: DateTime.now(),
      );
      await db.addScan(record);
      lastResult = record;
      lastWasDemo = prediction.demo;
      state = ScanState.done;
    } catch (e) {
      errorKey =
          e.toString().contains('model_missing') ? 'model_missing_note' : 'err_generic';
      state = ScanState.error;
    }
    history = await db.getScans(limit: 10);
    notifyListeners();
  }

  void reset() {
    state = ScanState.idle;
    lastResult = null;
    errorKey = 'err_generic';
    notifyListeners();
  }
}

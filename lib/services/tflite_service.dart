import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants.dart';

class ScanPrediction {
  final String label;
  final double confidence;
  final bool demo;

  const ScanPrediction({
    required this.label,
    required this.confidence,
    this.demo = false,
  });
}

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 224;
  bool _loaded = false;

  bool get isLoaded => _loaded && _interpreter != null;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(kLabelsAsset);
      _labels =
          raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (_labels.isEmpty) return;
      try {
        _interpreter = await Interpreter.fromAsset(
          kModelAsset,
          options: InterpreterOptions()..threads = 2,
        );
        final shape = _interpreter!.getInputTensor(0).shape;
        _inputSize = shape.length >= 3 ? shape[1] : 224;
        _loaded = true;
      } catch (_) {
        _loaded = false;
      }
    } catch (_) {
      _loaded = false;
    }
  }

  ScanPrediction predict(Uint8List bytes) {
    if (!isLoaded) {
      if (kDemoModelFallback) return _demoPredict(bytes);
      throw StateError('model_missing');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('bad_image');
    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);
    final input = [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final px = resized.getPixel(x, y);
          return <double>[
            px.r.toDouble() / 255.0,
            px.g.toDouble() / 255.0,
            px.b.toDouble() / 255.0,
          ];
        });
      }),
    ];
    final output = [List<double>.filled(_labels.length, 0.0)];
    _interpreter!.run(input, output);
    var bestIdx = 0;
    var bestVal = -1.0;
    for (var i = 0; i < output[0].length; i++) {
      if (output[0][i] > bestVal) {
        bestVal = output[0][i];
        bestIdx = i;
      }
    }
    return ScanPrediction(label: _labels[bestIdx], confidence: bestVal);
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }

  ScanPrediction _demoPredict(Uint8List bytes) {
    var sum = 0;
    for (var i = 0; i < bytes.length; i += 997) {
      sum += bytes[i];
    }
    const candidates = [
      'Tomato___Late_blight',
      'Tomato___Early_blight',
      'Potato___Early_blight',
      'Corn_(maize)___Common_rust_',
      'Grape___Black_rot',
      'Tomato___healthy',
    ];
    return ScanPrediction(
      label: candidates[sum % candidates.length],
      confidence: 0.80 + (sum % 15) / 100.0,
      demo: true,
    );
  }
}

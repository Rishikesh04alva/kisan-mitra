import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants.dart';

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

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 224;
  bool _loaded = false;

  static const double _uncertainThreshold = 0.55;

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
          options: InterpreterOptions()..threads = 4,
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

  /// Center-crops to a square (leaf fills frame, background trimmed),
  /// resizes, and averages predictions over 2 augmented views
  /// (original + horizontal flip) for more stable results.
  img.Image _prepare(img.Image src) {
    final w = src.width, h = src.height;
    final side = w < h ? w : h;
    final x0 = (w - side) ~/ 2, y0 = (h - side) ~/ 2;
    final cropped = img.copyCrop(src, x: x0, y: y0, width: side, height: side);
    return img.copyResize(cropped, width: _inputSize, height: _inputSize,
        interpolation: img.Interpolation.linear);
  }

  List<List<List<double>>> _tensor(img.Image im, bool flip) {
    final source = flip ? img.flipHorizontal(im) : im;
    return List.generate(_inputSize, (y) {
      return List.generate(_inputSize, (x) {
        final px = source.getPixel(x, y);
        // Match tf.keras mobilenet_v2.preprocess_input: [0,255] -> [-1,1].
        return <double>[
          px.r.toDouble() / 127.5 - 1.0,
          px.g.toDouble() / 127.5 - 1.0,
          px.b.toDouble() / 127.5 - 1.0,
        ];
      });
    });
  }

  void _runInference(List<List<List<double>>> input, List<double> out) {
    _interpreter!.run([input], [out]);
  }

  ScanPrediction predict(Uint8List bytes) {
    if (!isLoaded) {
      if (kDemoModelFallback) {
        final p = _demoPredict(bytes);
        return ScanPrediction(
            label: p.label, confidence: p.confidence, demo: true, uncertain: true);
      }
      throw StateError('model_missing');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('bad_image');
    final prepared = _prepare(decoded);

    final n = _labels.length;
    final acc = List<double>.filled(n, 0.0);
    final single = List<double>.filled(n, 0.0);

    for (final flip in [false, true]) {
      final input = _tensor(prepared, flip);
      _runInference(input, single);
      var sum = 0.0;
      var lo = 0.0, hi = 0.0;
      for (final v in single) {
        sum += v;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
      // Raw logits -> softmax; already-normalized scores pass through.
      if (hi > 1.001 || lo < -0.001 || (sum - 1.0).abs() > 0.05) {
        final maxV = hi;
        var expSum = 0.0;
        for (var i = 0; i < n; i++) {
          single[i] = math.exp(single[i] - maxV);
          expSum += single[i];
        }
        for (var i = 0; i < n; i++) {
          single[i] /= expSum;
        }
      }
      for (var i = 0; i < n; i++) {
        acc[i] += single[i] / 2.0;
      }
    }

    final ranked = List<int>.generate(n, (i) => i)
      ..sort((a, b) => acc[b].compareTo(acc[a]));
    final top = ranked.take(3)
        .map((i) => MapEntry(_labels[i], acc[i]))
        .toList(growable: false);

    return ScanPrediction(
      label: top.first.key,
      confidence: top.first.value,
      top: top,
      uncertain: top.first.value < _uncertainThreshold,
    );
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

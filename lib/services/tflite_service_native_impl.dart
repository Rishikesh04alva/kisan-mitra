import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants.dart';
import 'image_analysis_service.dart';
import 'scan_prediction.dart';
import 'tflite_service.dart';

TfliteServiceBase createPlatformTfliteService() => _NativeTfliteService();

class _NativeTfliteService extends TfliteServiceBase {
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 224;
  bool _loaded = false;

  static const double _uncertainThreshold = 0.55;
  static const double _blurThreshold = 18.0;

  @override
  bool get isLoaded => _loaded && _interpreter != null;

  @override
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(kLabelsAsset);
      _labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
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

  /// Square crop of the requested size from the image centre.
  /// [zoomFrac] < 1 crops a tighter region (drops background edges).
  img.Image _square(img.Image src, double zoomFrac) {
    final w = src.width, h = src.height;
    var side = (w < h ? w : h);
    final inner = (side * zoomFrac).round();
    final x0 = (w - inner) ~/ 2, y0 = (h - inner) ~/ 2;
    final cropped =
        img.copyCrop(src, x: x0, y: y0, width: inner, height: inner);
    return img.copyResize(cropped,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear);
  }

  List<List<List<double>>> _tensor(img.Image im, bool flip) {
    final source = flip ? img.flipHorizontal(im) : im;
    return List.generate(_inputSize, (y) {
      return List.generate(_inputSize, (x) {
        final px = source.getPixel(x, y);
        return <double>[
          px.r.toDouble() / 127.5 - 1.0,
          px.g.toDouble() / 127.5 - 1.0,
          px.b.toDouble() / 127.5 - 1.0,
        ];
      });
    });
  }

  /// Laplacian variance on the small square — cheap focus/blur estimate.
  double _blurScore(img.Image im) {
    final n = _inputSize;
    final g = Float64List(n * n);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final px = im.getPixel(x, y);
        g[y * n + x] = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
      }
    }
    var sum = 0.0, sumSq = 0.0;
    var count = 0;
    for (var y = 1; y < n - 1; y++) {
      for (var x = 1; x < n - 1; x++) {
        final c = g[y * n + x];
        final lap = (g[(y - 1) * n + x] +
                g[(y + 1) * n + x] +
                g[y * n + x - 1] +
                g[y * n + x + 1] -
                4 * c)
            .abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }
    if (count == 0) return 999;
    final mean = sum / count;
    return sumSq / count - mean * mean;
  }

  void _run(List<List<List<double>>> input, List<double> out) {
    _interpreter!.run([input], [out]);
  }

  /// Softmax-if-needed, then accumulate into [acc].
  void _accumulate(List<double> single, List<double> acc) {
    final n = single.length;
    var sum = 0.0;
    var lo = 0.0, hi = 0.0;
    for (final v in single) {
      sum += v;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
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
      acc[i] += single[i];
    }
  }

  @override
  ScanPrediction predict(Uint8List bytes) {
    if (!isLoaded) {
      if (kDemoModelFallback) {
        final p = ImageAnalysisService.analyzeImage(bytes);
        return ScanPrediction(
            label: p.label,
            confidence: p.confidence,
            demo: true,
            uncertain: true);
      }
      throw StateError('model_missing');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('bad_image');

    // Phone-camera JPEGs are frequently stored rotated (EXIF orientation).
    // Without this the model sees sideways leaves and misclassifies.
    final upright = img.bakeOrientation(decoded);

    final full = _square(upright, 1.0);
    final tight = _square(upright, 0.85);

    final blurry = _blurScore(full) < _blurThreshold;

    final n = _labels.length;
    final acc = List<double>.filled(n, 0.0);
    final single = List<double>.filled(n, 0.0);

    // 4-view test-time augmentation: {full, tight} x {original, flipped}.
    for (final view in [full, tight]) {
      for (final flip in [false, true]) {
        final input = _tensor(view, flip);
        _run(input, single);
        _accumulate(single, acc);
      }
    }
    for (var i = 0; i < n; i++) {
      acc[i] /= 4.0;
    }

    final ranked = List<int>.generate(n, (i) => i)
      ..sort((a, b) => acc[b].compareTo(acc[a]));
    final top = ranked
        .take(3)
        .map((i) => MapEntry(_labels[i], acc[i]))
        .toList(growable: false);

    return ScanPrediction(
      label: top.first.key,
      confidence: top.first.value,
      top: top,
      uncertain: top.first.value < _uncertainThreshold || blurry,
      blurry: blurry,
    );
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }
}

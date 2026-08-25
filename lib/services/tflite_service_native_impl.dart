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

  /// Downscale so the long side is at most [maxSide].
  img.Image _downscale(img.Image src, int maxSide) {
    final longest = src.width > src.height ? src.width : src.height;
    if (longest <= maxSide) return src;
    final f = maxSide / longest;
    return img.copyResize(src,
        width: (src.width * f).round(),
        height: (src.height * f).round(),
        interpolation: img.Interpolation.linear);
  }

  void _boxBlur(Uint8List plane, Uint16List dst, int w, int h, int rad) {
    final tmp = Uint16List(plane.length);
    final win = 2 * rad + 1;
    for (var y = 0; y < h; y++) {
      var sum = 0;
      final row = y * w;
      for (var x = -rad; x <= rad; x++) {
        sum += plane[row + x.clamp(0, w - 1)];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x] = sum ~/ win;
        final addX = (x + rad + 1).clamp(0, w - 1);
        final remX = (x - rad).clamp(0, w - 1);
        sum += plane[row + addX] - plane[row + remX];
      }
    }
    for (var x = 0; x < w; x++) {
      var sum = 0;
      for (var y = -rad; y <= rad; y++) {
        sum += tmp[y.clamp(0, h - 1) * w + x];
      }
      for (var y = 0; y < h; y++) {
        dst[y * w + x] = sum ~/ win;
        final addY = (y + rad + 1).clamp(0, h - 1);
        final remY = (y - rad).clamp(0, h - 1);
        sum += tmp[addY * w + x] - tmp[remY * w + x];
      }
    }
  }

  /// Auto-enhance a dull/low-quality photo so cheap phone cameras still get
  /// a usable reading: gamma normalisation toward mid-grey, per-channel
  /// percentile contrast stretch, then a mild unsharp mask.
  img.Image _enhance(img.Image src) {
    final w = src.width, h = src.height;
    final total = w * h;
    if (total == 0) return src;

    final r = Uint8List(total), g = Uint8List(total), b = Uint8List(total);
    var lsum = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final px = src.getPixel(x, y);
        final ri = px.r.toInt().clamp(0, 255);
        final gi = px.g.toInt().clamp(0, 255);
        final bi = px.b.toInt().clamp(0, 255);
        r[i] = ri;
        g[i] = gi;
        b[i] = bi;
        lsum += 0.299 * ri + 0.587 * gi + 0.114 * bi;
      }
    }

    final mean = lsum / total;
    var gamma = 1.0;
    if (mean > 4 && mean < 250) {
      gamma = (math.log(0.5) / math.log(mean / 255.0)).clamp(0.60, 1.80);
    }
    final gLut = List<int>.generate(256,
        (v) => ((math.pow(v / 255.0, gamma)) * 255.0).round().clamp(0, 255));

    List<int> stretchBounds(Uint8List plane) {
      final hist = List<int>.filled(256, 0);
      for (final v in plane) {
        hist[gLut[v]]++;
      }
      final edge = (total * 0.02).round();
      var lo = 0, hi = 255, cum = 0;
      for (var v = 0; v < 256; v++) {
        cum += hist[v];
        if (cum > edge) {
          lo = v;
          break;
        }
      }
      cum = 0;
      for (var v = 255; v >= 0; v--) {
        cum += hist[v];
        if (cum > edge) {
          hi = v;
          break;
        }
      }
      if (hi - lo < 24) return [0, 255];
      return [lo, hi];
    }

    List<int> buildLut(Uint8List plane) {
      final bnd = stretchBounds(plane);
      final span = (bnd[1] - bnd[0]).clamp(1, 255);
      return List<int>.generate(256, (v) {
        final gv = gLut[v];
        return ((gv - bnd[0]) * 255 ~/ span).clamp(0, 255);
      });
    }

    final rLut = buildLut(r), gLutC = buildLut(g), bLut = buildLut(b);
    for (var i = 0; i < total; i++) {
      r[i] = rLut[r[i]];
      g[i] = gLutC[g[i]];
      b[i] = bLut[b[i]];
    }

    const rad = 2;
    final br = Uint16List(total), bg = Uint16List(total), bb = Uint16List(total);
    _boxBlur(r, br, w, h, rad);
    _boxBlur(g, bg, w, h, rad);
    _boxBlur(b, bb, w, h, rad);

    for (var i = 0; i < total; i++) {
      r[i] = (r[i] * 135 ~/ 100 - br[i] * 35 ~/ 100).clamp(0, 255);
      g[i] = (g[i] * 135 ~/ 100 - bg[i] * 35 ~/ 100).clamp(0, 255);
      b[i] = (b[i] * 135 ~/ 100 - bb[i] * 35 ~/ 100).clamp(0, 255);
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        src.getPixel(x, y)
          ..r = r[i]
          ..g = g[i]
          ..b = b[i];
      }
    }
    return src;
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
  ScanPrediction predict(Uint8List bytes, {String? cropPrefix}) {
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

    final small = _downscale(upright, 512);
    final enhanced = _enhance(small);

    final full = _square(enhanced, 1.0);
    final tight = _square(enhanced, 0.85);

    // Focus gate runs on the UN-sharpened frame so our own enhancement
    // cannot hide a genuinely blurry photo.
    final blurry = _blurScore(_square(small, 1.0)) < _blurThreshold;

    final n = _labels.length;
    final acc = List<double>.filled(n, 0.0);
    final single = List<double>.filled(n, 0.0);

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
    var bestIdx = ranked.first;
    var filtered = false;

    // Crop constraint: the user told us which plant this is, so the winner
    // must come from that crop's classes. Global top-3 stay visible as
    // alternatives in case the crop hint itself was wrong.
    if (cropPrefix != null && cropPrefix.isNotEmpty) {
      final pfx = '${cropPrefix}___';
      for (final i in ranked) {
        if (_labels[i].startsWith(pfx)) {
          bestIdx = i;
          filtered = i != ranked.first;
          break;
        }
      }
    }

    final top = <MapEntry<String, double>>[
      MapEntry(_labels[bestIdx], acc[bestIdx]),
      for (final i in ranked)
        if (i != bestIdx) MapEntry(_labels[i], acc[i]),
    ].take(3).toList(growable: false);

    return ScanPrediction(
      label: top.first.key,
      confidence: top.first.value,
      top: top,
      uncertain: top.first.value < _uncertainThreshold || blurry,
      blurry: blurry,
      cropFiltered: filtered,
    );
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/models.dart';

class WeatherService {
  final http.Client _client = http.Client();

  Future<WeatherSnapshot?> fetchCurrent({
    double lat = kDefaultLat,
    double lon = kDefaultLon,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,precipitation',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final current = jsonDecode(res.body)['current'] as Map<String, dynamic>;
      return WeatherSnapshot(
        tempC: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toDouble(),
        rainMm: (current['precipitation'] as num? ?? 0).toDouble(),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

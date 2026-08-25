import 'package:flutter_test/flutter_test.dart';
import 'package:kisan_mitra/data/models/models.dart';
import 'package:kisan_mitra/providers/tracker_provider.dart';
import 'package:kisan_mitra/services/location_service.dart';
import 'package:kisan_mitra/services/nutrition_service.dart';

void main() {
  group('Weather & Location Tests', () {
    test('WeatherSnapshot initializes with real-time fields and emoji', () {
      final snap = WeatherSnapshot(
        tempC: 28.5,
        humidity: 62.0,
        rainMm: 0.0,
        weatherCode: 0,
        windSpeedKmH: 14.2,
        apparentTempC: 30.1,
        locationName: 'Nagpur, Maharashtra',
        lat: 21.1458,
        lon: 79.0882,
        isGpsLocation: true,
        fetchedAt: DateTime.now(),
      );

      expect(snap.tempC, 28.5);
      expect(snap.humidity, 62.0);
      expect(snap.weatherEmoji, '☀️');
      expect(snap.conditionKey, 'w_clear');
      expect(snap.isGpsLocation, isTrue);
      expect(snap.locationName, 'Nagpur, Maharashtra');
      expect(snap.isFresh(const Duration(hours: 1), DateTime.now()), isTrue);
    });

    test('UserLocation model works as expected', () {
      const loc = UserLocation(
        latitude: 18.5204,
        longitude: 73.8567,
        displayName: 'Pune, Maharashtra',
        isGps: true,
      );

      expect(loc.latitude, 18.5204);
      expect(loc.longitude, 73.8567);
      expect(loc.displayName, 'Pune, Maharashtra');
      expect(loc.isGps, isTrue);
    });

    test('TrackerProvider decide logic skips irrigation on rain', () {
      final now = DateTime.now();
      final since = now.subtract(const Duration(days: 5));
      final rainy = WeatherSnapshot(
        tempC: 24.0,
        humidity: 90.0,
        rainMm: 8.5,
        fetchedAt: now,
      );

      final res = TrackerProvider.decide(
        waterIntervalDays: 3,
        since: since,
        now: now,
        w: rainy,
      );

      expect(res.d, IrrigationDecision.skip);
      expect(res.reasonKey, 'r_rain_expected');
    });

    test('TrackerProvider decide logic handles heat stress with extra water', () {
      final now = DateTime.now();
      final since = now.subtract(const Duration(days: 5));
      final hot = WeatherSnapshot(
        tempC: 38.0,
        humidity: 35.0,
        rainMm: 0.0,
        fetchedAt: now,
      );

      final res = TrackerProvider.decide(
        waterIntervalDays: 3,
        since: since,
        now: now,
        w: hot,
      );

      expect(res.d, IrrigationDecision.water);
      expect(res.reasonKey, 'r_heat_stress');
    });
    test('NutritionService returns customized advice for Blight and Rust', () {
      final blight = NutritionService.getDiseaseNutritionAdvice('Tomato___Late_blight');
      expect(blight.nitrogenRule.contains('RESTRICT'), isTrue);
      expect(blight.potashPhosphorusRule.contains('POTASH'), isTrue);
      expect(blight.micronutrientSpray.contains('Zinc'), isTrue);

      final rust = NutritionService.getDiseaseNutritionAdvice('Corn_(maize)___Common_rust_');
      expect(rust.headline.contains('Silica'), isTrue);
      expect(rust.potashPhosphorusRule.contains('MOP'), isTrue);
    });

    test('LocationService has pre-populated popular farming hubs', () {
      expect(LocationService.popularLocations.isNotEmpty, isTrue);
      expect(LocationService.popularLocations.any((l) => l.displayName.contains('Nagpur')), isTrue);
      expect(LocationService.popularLocations.any((l) => l.displayName.contains('Pune')), isTrue);
    });
  });
}

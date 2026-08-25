import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/db/app_database.dart';
import '../data/models/models.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

class TrackerProvider extends ChangeNotifier {
  final AppDatabase db;
  final LocationService locationService = LocationService();
  final WeatherService weatherService = WeatherService();

  List<PlanRow> plan = [];
  WeatherSnapshot? weather;
  bool weatherStale = true;
  bool loadingWeather = false;
  bool isLocating = false;
  String? locationMessage;
  DateTime? lastRefreshed;

  TrackerProvider(this.db);

  static ({IrrigationDecision d, String reasonKey}) decide({
    required int waterIntervalDays,
    required DateTime since,
    required DateTime now,
    required WeatherSnapshot? w,
  }) {
    final daysSince = dayDiff(now, since);
    if (w != null && w.rainMm >= 5.0) {
      return (d: IrrigationDecision.skip, reasonKey: 'r_rain_expected');
    }
    if (daysSince >= waterIntervalDays) {
      if (daysSince > waterIntervalDays && w != null && w.tempC >= 35) {
        return (d: IrrigationDecision.water, reasonKey: 'r_heat_stress');
      }
      return (d: IrrigationDecision.water, reasonKey: 'r_due');
    }
    return (d: IrrigationDecision.monitor, reasonKey: 'r_soil_moist_ok');
  }

  ScanRecord? latestScan;

  Future<void> refresh() async {
    final now = DateTime.now();
    final crops = await db.getCrops();
    final byId = {for (final c in crops) c.id: c};
    final plots = (await db.getPlots()).where((p) => p.isPlanted).toList();
    weather = await db.getCachedWeather();
    latestScan = await db.latestScan();
    weatherStale =
        weather == null || !weather!.isFresh(const Duration(hours: 4), now);
    final rows = <PlanRow>[];
    for (final plot in plots) {
      final crop = byId[plot.cropId!];
      if (crop == null) continue;
      final lastWatered = await db.lastWateredOn(plot.id);
      final baseline = lastWatered ?? plot.sowingDate!;
      final result = decide(
        waterIntervalDays: crop.waterIntervalDays,
        since: baseline,
        now: now,
        w: weather,
      );
      final elapsed = dayDiff(now, plot.sowingDate!);
      rows.add(
        PlanRow(
          plot: plot,
          decision: result.d,
          reasonKey: result.reasonKey,
          fertDue: _fertDue(crop, elapsed),
        ),
      );
    }
    rows.sort((a, b) => b.decision.index.compareTo(a.decision.index));
    plan = rows;
    lastRefreshed = now;
    notifyListeners();
  }

  Future<void> setLocation({
    required double lat,
    required double lon,
    required String name,
    bool isGps = false,
  }) async {
    await refreshWeatherOnline(
      requestGps: false,
      customLat: lat,
      customLon: lon,
      customLocationName: name,
    );
  }

  static FertStage? _fertDue(Crop crop, int elapsedDaysSinceSowing) {
    for (final s in crop.stages) {
      if (elapsedDaysSinceSowing >= s.fromDay &&
          elapsedDaysSinceSowing <= s.toDay) {
        return s;
      }
    }
    return null;
  }

  Future<void> markWatered(String fieldId) async {
    await db.logWater(fieldId, DateTime.now());
    await refresh();
  }

  Future<bool> refreshWeatherOnline({
    WeatherService? service,
    bool requestGps = true,
    double? customLat,
    double? customLon,
    String? customLocationName,
  }) async {
    loadingWeather = true;
    locationMessage = null;
    notifyListeners();

    final ws = service ?? weatherService;
    double lat = customLat ?? kDefaultLat;
    double lon = customLon ?? kDefaultLon;
    String? locationName = customLocationName;
    bool isGps = false;

    if (customLat == null && requestGps) {
      isLocating = true;
      notifyListeners();
      try {
        final locRes = await locationService.getCurrentLocation(
          requestPermission: true,
        );
        lat = locRes.location.latitude;
        lon = locRes.location.longitude;
        locationName = locRes.location.displayName;
        isGps = locRes.isGpsSuccess;
        if (!locRes.isGpsSuccess && locRes.errorMessage != null) {
          locationMessage = locRes.errorMessage;
        }
      } catch (e) {
        locationMessage = 'Could not access GPS. Using default location.';
      } finally {
        isLocating = false;
      }
    } else if (weather != null && weather!.lat != null && weather!.lon != null) {
      lat = weather!.lat!;
      lon = weather!.lon!;
      locationName = weather!.locationName;
      isGps = weather!.isGpsLocation;
    }

    final fresh = await ws.fetchCurrent(
      lat: lat,
      lon: lon,
      locationName: locationName,
      isGpsLocation: isGps,
    );

    if (fresh != null) {
      await db.saveWeather(fresh);
    }
    loadingWeather = false;
    await refresh();
    return fresh != null;
  }

  Future<int> countPlotsNeedingWater() async {
    final crops = await db.getCrops();
    final byId = {for (final c in crops) c.id: c};
    final plots = (await db.getPlots()).where((p) => p.isPlanted).toList();
    final cached = await db.getCachedWeather();
    final now = DateTime.now();
    var count = 0;
    for (final p in plots) {
      final crop = byId[p.cropId!];
      if (crop == null) continue;
      final baseline = await db.lastWateredOn(p.id) ?? p.sowingDate!;
      final result = decide(
        waterIntervalDays: crop.waterIntervalDays,
        since: baseline,
        now: now,
        w: cached,
      );
      if (result.d == IrrigationDecision.water) count++;
    }
    return count;
  }

  @override
  void dispose() {
    locationService.dispose();
    weatherService.dispose();
    super.dispose();
  }
}

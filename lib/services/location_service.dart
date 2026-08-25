import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/models.dart';

class LocationResult {
  final UserLocation location;
  final bool isGpsSuccess;
  final String? errorMessage;
  final bool permissionDenied;

  const LocationResult({
    required this.location,
    required this.isGpsSuccess,
    this.errorMessage,
    this.permissionDenied = false,
  });
}

class LocationService {
  final http.Client _client = http.Client();

  static const List<UserLocation> popularLocations = [
    UserLocation(latitude: 21.1458, longitude: 79.0882, displayName: 'Nagpur, Maharashtra'),
    UserLocation(latitude: 19.9975, longitude: 73.7898, displayName: 'Nashik, Maharashtra'),
    UserLocation(latitude: 18.5204, longitude: 73.8567, displayName: 'Pune, Maharashtra'),
    UserLocation(latitude: 19.8762, longitude: 75.3433, displayName: 'Chhatrapati Sambhajinagar, MH'),
    UserLocation(latitude: 16.7050, longitude: 74.2433, displayName: 'Kolhapur, Maharashtra'),
    UserLocation(latitude: 20.9374, longitude: 77.7796, displayName: 'Amravati, Maharashtra'),
    UserLocation(latitude: 22.7196, longitude: 75.8577, displayName: 'Indore, Madhya Pradesh'),
    UserLocation(latitude: 23.2599, longitude: 77.4126, displayName: 'Bhopal, Madhya Pradesh'),
    UserLocation(latitude: 30.9010, longitude: 75.8573, displayName: 'Ludhiana, Punjab'),
    UserLocation(latitude: 29.6857, longitude: 76.9905, displayName: 'Karnal, Haryana'),
    UserLocation(latitude: 11.0168, longitude: 76.9558, displayName: 'Coimbatore, Tamil Nadu'),
    UserLocation(latitude: 10.7870, longitude: 79.1378, displayName: 'Thanjavur, Tamil Nadu'),
    UserLocation(latitude: 16.3067, longitude: 80.4365, displayName: 'Guntur, Andhra Pradesh'),
    UserLocation(latitude: 17.9689, longitude: 79.5941, displayName: 'Warangal, Telangana'),
    UserLocation(latitude: 15.8497, longitude: 74.4977, displayName: 'Belagavi, Karnataka'),
    UserLocation(latitude: 12.2958, longitude: 76.6394, displayName: 'Mysuru, Karnataka'),
    UserLocation(latitude: 25.3176, longitude: 82.9739, displayName: 'Varanasi, Uttar Pradesh'),
    UserLocation(latitude: 25.5941, longitude: 85.1376, displayName: 'Patna, Bihar'),
    UserLocation(latitude: 26.9124, longitude: 75.7873, displayName: 'Jaipur, Rajasthan'),
    UserLocation(latitude: 23.0225, longitude: 72.5714, displayName: 'Ahmedabad, Gujarat'),
    UserLocation(latitude: 22.3039, longitude: 70.8022, displayName: 'Rajkot, Gujarat'),
    UserLocation(latitude: 21.2514, longitude: 81.6296, displayName: 'Raipur, Chhattisgarh'),
    UserLocation(latitude: 20.2961, longitude: 85.8245, displayName: 'Bhubaneswar, Odisha'),
  ];

  /// Gets the current location via GPS or IP Geolocation fallback.
  Future<LocationResult> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    // 1. Try GPS via Geolocator
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().catchError((_) => false);
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission().catchError((_) => LocationPermission.denied);
        if (permission == LocationPermission.denied && requestPermission) {
          permission = await Geolocator.requestPermission().catchError((_) => LocationPermission.denied);
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position? position;
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 6),
              ),
            );
          } catch (_) {
            position = await Geolocator.getLastKnownPosition();
          }

          if (position != null) {
            final placeName = await reverseGeocode(position.latitude, position.longitude);
            return LocationResult(
              location: UserLocation(
                latitude: position.latitude,
                longitude: position.longitude,
                displayName: placeName ?? '${position.latitude.toStringAsFixed(2)}°N, ${position.longitude.toStringAsFixed(2)}°E',
                isGps: true,
              ),
              isGpsSuccess: true,
            );
          }
        }
      }
    } catch (_) {}

    // 2. Try IP-based Geolocation fallback (works universally in browser & desktop)
    final ipLoc = await getIpLocation();
    if (ipLoc != null) {
      return LocationResult(
        location: ipLoc,
        isGpsSuccess: true,
        errorMessage: null,
      );
    }

    // 3. Final fallback to default agricultural location
    return const LocationResult(
      location: UserLocation(
        latitude: kDefaultLat,
        longitude: kDefaultLon,
        displayName: 'Nagpur, Maharashtra',
        isGps: false,
      ),
      isGpsSuccess: false,
      errorMessage: 'Could not access GPS. Using default region.',
    );
  }

  /// IP-based geolocation fallback for instant, accurate city coordinates.
  Future<UserLocation?> getIpLocation() async {
    try {
      final uri = Uri.parse('https://ipwho.is/');
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble();
          final city = data['city'] as String?;
          final region = data['region'] as String?;
          if (lat != null && lon != null) {
            final name = (city != null && region != null)
                ? '$city, $region'
                : (city ?? region ?? 'Detected Location');
            return UserLocation(
              latitude: lat,
              longitude: lon,
              displayName: name,
              isGps: true,
            );
          }
        }
      }
    } catch (_) {}

    // Secondary IP API fallback
    try {
      final uri = Uri.parse('https://ipapi.co/json/');
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final city = data['city'] as String?;
        final region = data['region'] as String?;
        if (lat != null && lon != null) {
          final name = (city != null && region != null)
              ? '$city, $region'
              : (city ?? region ?? 'Detected Location');
          return UserLocation(
            latitude: lat,
            longitude: lon,
            displayName: name,
            isGps: true,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Searches Indian cities/districts via Open-Meteo Geocoding API.
  Future<List<UserLocation>> searchCities(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return [];
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=$clean&count=6&language=en&format=json',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null) {
          return results.map((r) {
            final name = r['name'] as String? ?? clean;
            final admin1 = r['admin1'] as String?;
            final country = r['country'] as String? ?? 'India';
            final label = admin1 != null ? '$name, $admin1' : '$name, $country';
            return UserLocation(
              latitude: (r['latitude'] as num).toDouble(),
              longitude: (r['longitude'] as num).toDouble(),
              displayName: label,
              isGps: false,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Reverse geocodes coordinates to a human-readable location name.
  Future<String?> reverseGeocode(double lat, double lon) async {
    if (!kIsWeb) {
      try {
        final placemarks = await geo.placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if (p.locality != null && p.locality!.isNotEmpty) {
            parts.add(p.locality!);
          } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
            parts.add(p.subAdministrativeArea!);
          }
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final city = (data['city'] as String?)?.trim();
        final locality = (data['locality'] as String?)?.trim();
        final admin = (data['principalSubdivision'] as String?)?.trim();
        final main = (city != null && city.isNotEmpty)
            ? city
            : (locality != null && locality.isNotEmpty ? locality : null);
        if (main != null && admin != null && admin.isNotEmpty) {
          return '$main, $admin';
        } else if (main != null) {
          return main;
        } else if (admin != null && admin.isNotEmpty) {
          return admin;
        }
      }
    } catch (_) {}

    return '${lat.toStringAsFixed(2)}°N, ${lon.toStringAsFixed(2)}°E';
  }

  void dispose() => _client.close();
}

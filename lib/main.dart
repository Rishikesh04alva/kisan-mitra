import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'data/models/models.dart';
import 'services/sync_service.dart';
import 'services/tflite_service.dart';

void main() {
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase.instance;
    await db.init();

    // Seed crops
    try {
      final cropsRaw = await rootBundle.loadString('assets/data/crops.json');
      final crops = (jsonDecode(cropsRaw) as List)
          .map((e) => Crop.fromJson(e as Map<String, dynamic>))
          .toList();
      await db.seedCrops(crops);
    } catch (_) {}

    // Seed schemes
    try {
      final schemesRaw = await rootBundle.loadString('assets/data/schemes.json');
      final schemes = (jsonDecode(schemesRaw) as List)
          .map((e) => Scheme.fromJson(e as Map<String, dynamic>))
          .toList();
      await db.seedSchemes(schemes);
    } catch (_) {}

    final tflite = createTfliteService();
    await tflite.load();

    // Workmanager only works on mobile — skip on web
    if (!kIsWeb) {
      try {
        await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
        await Workmanager().registerPeriodicTask(
          'kisan-sync-unique',
          kPeriodicSyncTask,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );
      } catch (_) {}
    }

    const firebaseReady = false;

    runApp(KisanMitraApp(
      db: db,
      tflite: tflite,
      firebaseReady: firebaseReady,
    ));
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

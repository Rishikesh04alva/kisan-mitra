import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'data/models/models.dart';
import 'services/sync_service.dart';
import 'services/tflite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.instance;
  await db.init();
  await _seed(db);

  final tflite = TfliteService();
  await tflite.load();

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

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {}

  runApp(KisanMitraApp(
    db: db,
    tflite: tflite,
    firebaseReady: firebaseReady,
  ));
}

Future<void> _seed(AppDatabase db) async {
  try {
    final cropsRaw = await rootBundle.loadString('assets/data/crops.json');
    final crops = (jsonDecode(cropsRaw) as List)
        .map((e) => Crop.fromJson(e as Map<String, dynamic>))
        .toList();
    await db.seedCrops(crops);

    final schemesRaw = await rootBundle.loadString('assets/data/schemes.json');
    final schemes = (jsonDecode(schemesRaw) as List)
        .map((e) => Scheme.fromJson(e as Map<String, dynamic>))
        .toList();
    await db.seedSchemes(schemes);
  } catch (_) {}
}

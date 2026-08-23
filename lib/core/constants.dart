import 'package:flutter/material.dart';

const double kTouchTarget = 56.0;
const double kBorderWidth = 2.5;
const double kRadius = 10.0;
const Offset kShadow = Offset(4, 4);

const String kModelAsset = 'assets/models/plant_disease.tflite';
const String kLabelsAsset = 'assets/models/plant_disease_labels.txt';

const String kSyncBaseUrl = 'https://api.kisanmitra.example/v1';

const bool kDemoModelFallback = true;

const int kGridCols = 3;
const int kGridRows = 4;

const double kDefaultLat = 21.1458;
const double kDefaultLon = 79.0882;

const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('mr'),
  Locale('kn'),
  Locale('ta'),
  Locale('te'),
  Locale('ml'),
];

const Map<String, String> kSpeechLocale = {
  'en': 'en_IN',
  'hi': 'hi_IN',
  'mr': 'mr_IN',
  'kn': 'kn_IN',
  'ta': 'ta_IN',
  'te': 'te_IN',
  'ml': 'ml_IN',
};

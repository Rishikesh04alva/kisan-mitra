import 'package:flutter/material.dart';
import '../../core/l10n.dart';

int dayDiff(DateTime a, DateTime b) {
  final x = DateTime(a.year, a.month, a.day);
  final y = DateTime(b.year, b.month, b.day);
  return x.difference(y).inDays;
}

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDate(String s) => DateTime.parse(s);

class FertStage {
  final int fromDay;
  final int toDay;
  final String labelKey;
  final Map<String, double> fert;

  const FertStage({
    required this.fromDay,
    required this.toDay,
    required this.labelKey,
    this.fert = const {},
  });

  factory FertStage.fromJson(Map<String, dynamic> j) => FertStage(
        fromDay: j['from'] as int,
        toDay: j['to'] as int,
        labelKey: j['label'] as String,
        fert: ((j['fert'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
}

class Crop {
  final String id;
  final String nameKey;
  final String icon;
  final int waterIntervalDays;
  final int harvestDays;
  final List<FertStage> stages;

  const Crop({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.waterIntervalDays,
    required this.harvestDays,
    required this.stages,
  });

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
        id: j['id'] as String,
        nameKey: j['nameKey'] as String,
        icon: j['icon'] as String,
        waterIntervalDays: j['waterIntervalDays'] as int,
        harvestDays: j['harvestDays'] as int,
        stages: (j['stages'] as List)
            .map((e) => FertStage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String localName(BuildContext context) {
    return S.of(context).t(nameKey);
  }
}

class DiseaseInfo {
  final String label;
  final String crop;
  final String severity;
  final String desc;
  final String organic;
  final String chemical;
  final String prevention;

  const DiseaseInfo({
    required this.label,
    required this.crop,
    required this.severity,
    required this.desc,
    required this.organic,
    required this.chemical,
    required this.prevention,
  });

  factory DiseaseInfo.fromJson(String label, Map<String, dynamic> j) =>
      DiseaseInfo(
        label: label,
        crop: j['crop'] as String? ?? '',
        severity: j['severity'] as String? ?? 'medium',
        desc: j['desc'] as String? ?? '',
        organic: j['organic'] as String? ?? '',
        chemical: j['chemical'] as String? ?? '',
        prevention: j['prevention'] as String? ?? '',
      );
}

class FieldPlot {
  final String id;
  final int rowIdx;
  final int colIdx;
  final String? cropId;
  final DateTime? sowingDate;
  final double areaAcres;

  const FieldPlot({
    required this.id,
    required this.rowIdx,
    required this.colIdx,
    this.cropId,
    this.sowingDate,
    this.areaAcres = 1.0,
  });

  bool get isPlanted => cropId != null && sowingDate != null;
}

class ScanRecord {
  final String id;
  final String imagePath;
  final String label;
  final double confidence;
  final DateTime createdAt;
  final String? fieldId;

  const ScanRecord({
    required this.id,
    required this.imagePath,
    required this.label,
    required this.confidence,
    required this.createdAt,
    this.fieldId,
  });

  bool get healthy => label.toLowerCase().contains('healthy');

  String get txKey {
    final l = label.toLowerCase();
    if (l.contains('healthy')) return 'tx_none';
    if (l.contains('late_blight')) return 'tx_late_blight';
    if (l.contains('rust')) return 'tx_rust';
    if (l.contains('mildew')) return 'tx_mildew';
    if (l.contains('rot')) return 'tx_rot';
    if (l.contains('bacterial')) return 'tx_bacterial';
    if (l.contains('mite')) return 'tx_mite';
    if (l.contains('virus') || l.contains('mosaic') || l.contains('greening')) {
      return 'tx_virus_vector';
    }
    if (l.contains('blight') ||
        l.contains('spot') ||
        l.contains('mold') ||
        l.contains('scorch') ||
        l.contains('measles') ||
        l.contains('scab')) {
      return 'tx_fungal_spray';
    }
    return 'tx_generic';
  }
}

class Scheme {
  final String id;
  final String nameEn;
  final String nameHi;
  final String nameMr;
  final String nameKn;
  final String nameTa;
  final String nameTe;
  final String nameMl;
  final String category;
  final String state;
  final List<String> eligibility;
  final String benEn;
  final String benHi;
  final String benMr;
  final String benKn;
  final String benTa;
  final String benTe;
  final String benMl;
  final String url;
  final String phone;

  const Scheme({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.nameMr,
    this.nameKn = '',
    this.nameTa = '',
    this.nameTe = '',
    this.nameMl = '',
    required this.category,
    required this.state,
    required this.eligibility,
    required this.benEn,
    required this.benHi,
    required this.benMr,
    this.benKn = '',
    this.benTa = '',
    this.benTe = '',
    this.benMl = '',
    required this.url,
    required this.phone,
  });

  String name(String lang) {
    switch (lang) {
      case 'hi':
        return nameHi;
      case 'mr':
        return nameMr;
      case 'kn':
        return nameKn.isNotEmpty ? nameKn : nameEn;
      case 'ta':
        return nameTa.isNotEmpty ? nameTa : nameEn;
      case 'te':
        return nameTe.isNotEmpty ? nameTe : nameEn;
      case 'ml':
        return nameMl.isNotEmpty ? nameMl : nameEn;
      default:
        return nameEn;
    }
  }

  String benefit(String lang) {
    switch (lang) {
      case 'hi':
        return benHi;
      case 'mr':
        return benMr;
      case 'kn':
        return benKn.isNotEmpty ? benKn : benEn;
      case 'ta':
        return benTa.isNotEmpty ? benTa : benEn;
      case 'te':
        return benTe.isNotEmpty ? benTe : benEn;
      case 'ml':
        return benMl.isNotEmpty ? benMl : benEn;
      default:
        return benEn;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'nameMr': nameMr,
        'nameKn': nameKn,
        'nameTa': nameTa,
        'nameTe': nameTe,
        'nameMl': nameMl,
        'category': category,
        'state': state,
        'elig': eligibility.join('|'),
        'benEn': benEn,
        'benHi': benHi,
        'benMr': benMr,
        'benKn': benKn,
        'benTa': benTa,
        'benTe': benTe,
        'benMl': benMl,
        'url': url,
        'phone': phone,
      };

  factory Scheme.fromMap(Map<String, dynamic> m) => Scheme(
        id: m['id'] as String,
        nameEn: m['nameEn'] as String,
        nameHi: m['nameHi'] as String,
        nameMr: m['nameMr'] as String,
        nameKn: m['nameKn'] as String? ?? '',
        nameTa: m['nameTa'] as String? ?? '',
        nameTe: m['nameTe'] as String? ?? '',
        nameMl: m['nameMl'] as String? ?? '',
        category: m['category'] as String,
        state: m['state'] as String? ?? 'ALL',
        eligibility: (m['elig'] as String? ?? '').split('|').where((e) => e.isNotEmpty).toList(),
        benEn: m['benEn'] as String,
        benHi: m['benHi'] as String,
        benMr: m['benMr'] as String,
        benKn: m['benKn'] as String? ?? '',
        benTa: m['benTa'] as String? ?? '',
        benTe: m['benTe'] as String? ?? '',
        benMl: m['benMl'] as String? ?? '',
        url: m['url'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
      );

  factory Scheme.fromJson(Map<String, dynamic> j) => Scheme(
        id: j['id'] as String,
        nameEn: j['nameEn'] as String,
        nameHi: j['nameHi'] as String,
        nameMr: j['nameMr'] as String,
        nameKn: j['nameKn'] as String? ?? '',
        nameTa: j['nameTa'] as String? ?? '',
        nameTe: j['nameTe'] as String? ?? '',
        nameMl: j['nameMl'] as String? ?? '',
        category: j['category'] as String,
        state: j['state'] as String? ?? 'ALL',
        eligibility:
            (j['eligibility'] as List? ?? []).map((e) => e.toString()).toList(),
        benEn: j['benefitEn'] as String,
        benHi: j['benefitHi'] as String,
        benMr: j['benefitMr'] as String,
        benKn: j['benefitKn'] as String? ?? '',
        benTa: j['benefitTa'] as String? ?? '',
        benTe: j['benefitTe'] as String? ?? '',
        benMl: j['benefitMl'] as String? ?? '',
        url: j['url'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
      );
}

class WeatherSnapshot {
  final double tempC;
  final double humidity;
  final double rainMm;
  final int weatherCode;
  final double windSpeedKmH;
  final double? apparentTempC;
  final String? locationName;
  final double? lat;
  final double? lon;
  final DateTime fetchedAt;
  final bool isGpsLocation;

  const WeatherSnapshot({
    required this.tempC,
    required this.humidity,
    required this.rainMm,
    this.weatherCode = 0,
    this.windSpeedKmH = 0.0,
    this.apparentTempC,
    this.locationName,
    this.lat,
    this.lon,
    required this.fetchedAt,
    this.isGpsLocation = false,
  });

  bool isFresh(Duration maxAge, DateTime now) =>
      now.difference(fetchedAt) <= maxAge;

  String get weatherEmoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 48) return '🌫️';
    if (weatherCode <= 57) return '🌦️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '🌨️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 99) return '⛈️';
    return '🌤️';
  }

  String get conditionKey {
    if (weatherCode == 0) return 'w_clear';
    if (weatherCode <= 3) return 'w_partly_cloudy';
    if (weatherCode <= 48) return 'w_fog';
    if (weatherCode <= 57) return 'w_drizzle';
    if (weatherCode <= 67) return 'w_rain';
    if (weatherCode <= 77) return 'w_snow';
    if (weatherCode <= 82) return 'w_showers';
    if (weatherCode <= 99) return 'w_thunderstorm';
    return 'w_clear';
  }
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String displayName;
  final bool isGps;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.isGps = false,
  });
}

enum IrrigationDecision { water, skip, monitor }

class PlanRow {
  final FieldPlot plot;
  final IrrigationDecision decision;
  final String reasonKey;
  final FertStage? fertDue;

  const PlanRow({
    required this.plot,
    required this.decision,
    required this.reasonKey,
    this.fertDue,
  });
}

class ChatMsg {
  final String text;
  final bool fromUser;
  final DateTime time;

  const ChatMsg({required this.text, required this.fromUser, required this.time});
}

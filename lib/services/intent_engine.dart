import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class IntentDef {
  final String id;
  final Map<String, List<String>> keywords;

  const IntentDef({required this.id, required this.keywords});
}

class IntentEngine {
  final List<IntentDef> _intents = [];
  bool loaded = false;

  Future<void> load() async {
    if (loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/intents.json');
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        _intents.add(
          IntentDef(
            id: m['id'] as String,
            keywords: (m['keywords'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(
                k,
                (v as List).map((x) => x.toString()).toList(),
              ),
            ),
          ),
        );
      }
      loaded = true;
    } catch (_) {
      loaded = false;
    }
  }

  String match(String text, String lang) {
    if (_intents.isEmpty) return 'fallback';
    final normalized = normalize(text);
    var bestId = 'fallback';
    var bestScore = 0;
    for (final intent in _intents) {
      final keywords = [
        ...?intent.keywords['en'],
        ...?intent.keywords[lang],
      ];
      var score = 0;
      for (final kw in keywords) {
        final lower = kw.toLowerCase();
        if (lower.isNotEmpty && normalized.contains(lower)) {
          score += lower.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestId = intent.id;
      }
    }
    return bestId;
  }

  static String normalize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u0900-\u097F\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/db/app_database.dart';
import '../data/models/models.dart';
import '../services/intent_engine.dart';

typedef Tr = String Function(String key, [Map<String, String>? params]);

class AssistantProvider extends ChangeNotifier {
  final AppDatabase db;
  final IntentEngine engine;

  final List<ChatMsg> messages = [];
  bool listening = false;
  bool sttAvailable = false;

  final SpeechToText _stt = SpeechToText();

  AssistantProvider(this.db, this.engine);

  Future<void> ensureGreeting(Tr tr) async {
    await engine.load();
    if (messages.isNotEmpty) return;
    messages.add(
      ChatMsg(text: tr('greeting_reply'), fromUser: false, time: DateTime.now()),
    );
    notifyListeners();
  }

  Future<void> send(String text, String langCode, Tr tr) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    messages.add(ChatMsg(text: clean, fromUser: true, time: DateTime.now()));
    notifyListeners();
    final reply = await _respond(clean, langCode, tr);
    messages.add(
      ChatMsg(text: reply, fromUser: false, time: DateTime.now()),
    );
    notifyListeners();
  }

  Future<String> _respond(String text, String langCode, Tr tr) async {
    await engine.load();
    final intent = engine.match(text, langCode);
    switch (intent) {
      case 'greeting':
        return tr('greeting_reply');
      case 'water_status':
        final n = await _plotsNeedingWater();
        if (n == 0) return tr('water_none_reply');
        return tr('water_reply', {'count': '$n'});
      case 'fertilizer':
        return tr('fert_reply');
      case 'disease_help':
        return tr('disease_reply');
      case 'weather':
        return tr('weather_reply');
      case 'thanks':
        return tr('thanks_reply');
      case 'scheme_info':
        final scheme = await _findScheme(text);
        if (scheme != null) {
          final bullets =
              scheme.eligibility.take(3).map((e) => '- $e').join('\n');
          return '${scheme.name(langCode)}\n${scheme.benefit(langCode)}\n$bullets';
        }
        return tr('scheme_reply');
      default:
        return tr('fallback_reply');
    }
  }

  Future<int> _plotsNeedingWater() async {
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
      final daysSince = dayDiff(now, baseline);
      final rainExpected = cached != null && cached.rainMm >= 5.0;
      if (!rainExpected && daysSince >= crop.waterIntervalDays) count++;
    }
    return count;
  }

  Future<Scheme?> _findScheme(String text) async {
    final words = IntentEngine.normalize(text)
        .split(' ')
        .where((w) => w.length >= 4)
        .take(5)
        .toList();
    for (final w in words) {
      final found = await db.getSchemes(query: w);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }

  Future<bool> initSpeech() async {
    if (sttAvailable) return true;
    try {
      sttAvailable = await _stt.initialize();
    } catch (_) {
      sttAvailable = false;
    }
    return sttAvailable;
  }

  Future<void> toggleListening({
    required String localeId,
    required String langCode,
    required Tr tr,
  }) async {
    if (listening) {
      await _stopListeningQuietly();
      return;
    }
    final ok = await initSpeech();
    if (!ok) {
      messages.add(
        ChatMsg(text: tr('err_generic'), fromUser: false, time: DateTime.now()),
      );
      notifyListeners();
      return;
    }
    listening = true;
    notifyListeners();
    _stt.listen(
      localeId: localeId,
      listenMode: ListenMode.dictation,
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
      ),
      onResult: (result) async {
        if (result.finalResult == true) {
          await _stopListeningQuietly();
          final said = result.recognizedWords.trim();
          if (said.isNotEmpty) {
            await send(said, langCode, tr);
          }
        }
      },
    );
  }

  Future<void> _stopListeningQuietly() async {
    try {
      await _stt.stop();
    } catch (_) {}
    listening = false;
    notifyListeners();
  }
}

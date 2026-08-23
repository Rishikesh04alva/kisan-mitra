import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/db/app_database.dart';
import '../data/models/models.dart';
import '../services/intent_engine.dart';
import '../services/llm_service.dart';

typedef Tr = String Function(String key, [Map<String, String>? params]);

class AssistantProvider extends ChangeNotifier {
  final AppDatabase db;
  final IntentEngine engine;
  final GeminiService ai = GeminiService();

  static const _kAiKeySetting = 'gemini_api_key';

  final List<ChatMsg> messages = [];
  bool listening = false;
  bool sttAvailable = false;
  bool aiBusy = false;
  String? _aiKey;
  String? _lastQuestion;

  final SpeechToText _stt = SpeechToText();

  AssistantProvider(this.db, this.engine);

  bool get aiReady => _aiKey != null && _aiKey!.isNotEmpty;

  Future<void> loadAiKey() async {
    try {
      _aiKey = await db.getSetting(_kAiKeySetting);
    } catch (_) {
      _aiKey = null;
    }
    notifyListeners();
  }

  Future<void> saveAiKey(String key) async {
    final k = key.trim();
    _aiKey = k.isEmpty ? null : k;
    try {
      await db.saveSetting(_kAiKeySetting, k);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> ensureGreeting(Tr tr) async {
    await engine.load();
    await loadAiKey();
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

    await engine.load();
    final intent = engine.match(clean, langCode);
    _lastQuestion = clean;
    final useAi = aiReady && intent == 'fallback' && !aiBusy;

    ChatMsg? thinking;
    if (useAi) {
      aiBusy = true;
      thinking = ChatMsg(
          text: tr('ai_thinking'), fromUser: false, time: DateTime.now());
      messages.add(thinking);
      notifyListeners();
    }

    String reply;
    try {
      reply = useAi
          ? await _askAi(clean, langCode)
          : await _respond(intent, langCode, tr);
    } catch (_) {
      reply = tr('ai_error_reply');
    }

    if (thinking != null) {
      messages.remove(thinking);
      aiBusy = false;
    }
    messages.add(ChatMsg(text: reply, fromUser: false, time: DateTime.now()));
    notifyListeners();
  }

  Future<String> _askAi(String question, String langCode) async {
    final ctx = await _buildContext();
    return ai.ask(
      apiKey: _aiKey!,
      question: question,
      langCode: langCode,
      context: ctx,
    );
  }

  Future<String> _buildContext() async {
    try {
      final b = StringBuffer();
      final plots = (await db.getPlots()).where((p) => p.isPlanted).toList();
      if (plots.isNotEmpty) {
        final crops = {for (final c in await db.getCrops()) c.id: c};
        final names =
            plots.map((p) => crops[p.cropId]?.id ?? p.cropId).toSet().join(', ');
        b.write(' Farmer has ${plots.length} planted plot(s): $names.');
      }
      final w = await db.getCachedWeather();
      if (w != null) {
        b.write(
            ' Current weather at farm: ${w.tempC.round()}C, ${w.humidity.round()}% humidity.');
      }
      final scan = await db.latestScan();
      if (scan != null) {
        b.write(' Latest leaf scan result: ${scan.label}.');
      }
      return b.toString();
    } catch (_) {
      return '';
    }
  }

  Future<String> _respond(String intent, String langCode, Tr tr) async {
    switch (intent) {
      case 'greeting':
        return tr('greeting_reply');
      case 'water_status':
        final n = await _plotsNeedingWater();
        if (n == 0) return tr('water_none_reply');
        return tr('water_reply', {'count': '$n'});
      case 'fertilizer':
        return tr('fert_reply');
      case 'fert_how':
        return tr('fert_how_reply');
      case 'disease_help':
        return tr('disease_reply');
      case 'pest_advice':
        return tr('pest_reply');
      case 'weather':
        return tr('weather_reply');
      case 'thanks':
        return tr('thanks_reply');
      case 'scheme_info':
        final scheme = await _findScheme(_lastQuestion ?? '');
        if (scheme != null) {
          final bullets =
              scheme.eligibility.take(3).map((e) => '- $e').join('\n');
          return '${scheme.name(langCode)}\n${scheme.benefit(langCode)}\n$bullets';
        }
        return tr('scheme_reply');
      case 'market_price':
        return tr('market_reply');
      case 'seed_advice':
        return tr('seed_reply');
      case 'soil_test':
        return tr('soil_reply');
      case 'insurance':
        return tr('insure_reply');
      case 'machinery':
        return tr('machine_reply');
      case 'storage':
        return tr('store_reply');
      case 'organic':
        return tr('organic_reply');
      case 'sowing_window':
        return tr('sow_window_reply');
      case 'harvest_timing':
        return tr('harvest_reply');
      case 'helpline':
        return tr('helpline_reply');
      case 'irrigation_methods':
        return tr('irrigation_method_reply');
      case 'app_help':
        return tr('help_reply');
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

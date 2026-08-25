import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  // ─── Provider configuration (set via --dart-define at build time) ──────
  // Supported providers: 'gemini', 'openrouter', 'groq', 'proxy'
  static const _provider = String.fromEnvironment('AI_PROVIDER', defaultValue: 'gemini');
  static const defaultApiKey = String.fromEnvironment('AI_API_KEY');
  static const _proxyUrl = String.fromEnvironment('PROXY_URL');
  static const _apiSecret = String.fromEnvironment('API_SECRET');

  // Endpoint URLs per provider
  static const _endpoints = {
    'gemini': 'https://generativelanguage.googleapis.com/v1beta/openai/',
    'openrouter': 'https://openrouter.ai/api/v1/chat/completions',
    'groq': 'https://api.groq.com/openai/v1/chat/completions',
  };

  // Default model per provider
  static const _models = {
    'gemini': 'gemini-2.0-flash',
    'openrouter': 'google/gemini-2.5-flash',
    'groq': 'llama-3.3-70b-versatile',
  };

  String get _endpoint => _endpoints[_provider] ?? _endpoints['gemini']!;
  String get _model => _models[_provider] ?? _models['gemini']!;
  bool get useProxy => _proxyUrl.isNotEmpty;

  static const _langNames = {
    'en': 'English',
    'hi': 'Hindi (Devanagari script)',
    'mr': 'Marathi (Devanagari script)',
    'kn': 'Kannada',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
  };

  final http.Client _client = http.Client();

  Future<String> ask({
    required String apiKey,
    required String question,
    String langCode = 'en',
    String context = '',
    List<Map<String, String>> history = const [],
  }) async {
    final langName = _langNames[langCode] ?? 'English';
    final system =
        'You are Kisan Mitra, a warm and patient expert agricultural advisor for small and marginal farmers across India. '
        'You specialise in Indian conditions: monsoon timing, kharif/rabi/summer seasons, common Indian crops '
        '(rice, wheat, cotton, maize, soybean, sugarcane, pulses, oilseeds, vegetables), and low-cost organic + chemical practices. '
        'Always answer ONLY in $langName. Maximum 100 words. Plain text only — no markdown, no asterisks, no bullet symbols. '
        'Use very simple words an ordinary farmer understands. Speak warmly like a trusted friend, not a professor. '
        'Give practical, actionable advice suited to Indian farming conditions. '
        'For pesticide or fertilizer recommendations: always give exact dosage in grams per litre or kg per acre, '
        'mention the crop stage when to apply, and warn to spray in morning or evening (not in hot sun). '
        'Always recommend wearing gloves and mask when handling chemicals. '
        'For disease/pest questions: first help identify the problem, then suggest organic control first, chemical spray only if severe. '
        'Mention free government schemes or helplines when relevant (Kisan Call Center 1800-180-1551, e-NAM, PM-KISAN). '
        'For weather questions: explain how it affects crops and what the farmer should do. '
        'If you are not sure, say so honestly rather than guessing. '
        'Never give advice that could be dangerous (e.g., recommend highly toxic pesticides without proper warnings). '
        'You can discuss: irrigation, fertilizer, seeds, soil health, disease, pests, weather, market prices, '
        'government schemes, insurance, storage, organic farming, sowing and harvest timing.';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];
    // Add conversation history for context continuity
    for (final msg in history) {
      messages.add(msg);
    }
    final user = context.isNotEmpty
        ? '$context\n\nFarmer question: $question'
        : 'Farmer question: $question';

    final payload = {
      'model': _model,
      'messages': [
        ...messages,
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.4,
      'max_tokens': 300,
      'top_p': 0.9,
      'stream': false,
    };

    http.Response res;

    if (useProxy) {
      // ── Proxy mode: server holds the API key ──
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (_apiSecret.isNotEmpty) {
        headers['X-Api-Secret'] = _apiSecret;
      }
      res = await _client
          .post(
            Uri.parse('$_proxyUrl/v1/chat'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw Exception('proxy_${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      if (reply == null || reply.trim().isEmpty) {
        throw Exception('proxy_empty');
      }
      return reply.trim();
    } else {
      // ── Direct mode: calls the provider API directly ──
      // Build auth header based on provider
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (_provider == 'gemini') {
        // Gemini uses query param for API key
        final url = '$_endpoint?key=$apiKey';
        res = await _client
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        // OpenRouter, Groq, and others use Bearer token
        headers['Authorization'] = 'Bearer $apiKey';
        if (_provider == 'openrouter') {
          headers['X-Title'] = 'Kisan Mitra';
        }
        res = await _client
            .post(
              Uri.parse(_endpoint),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));
      }

      if (res.statusCode != 200) {
        throw Exception('${_provider}_${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('${_provider}_no_choices');
      }
      final content =
          ((choices.first as Map)['message'] as Map)['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw Exception('${_provider}_empty');
      }
      return content.trim();
    }
  }

  void dispose() => _client.close();
}

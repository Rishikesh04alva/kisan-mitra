import 'dart:convert';

import 'package:http/http.dart' as http;

class AiService {
  static const defaultApiKey = String.fromEnvironment('OPENROUTER_KEY');
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'google/gemini-2.5-flash';

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
  }) async {
    final langName = _langNames[langCode] ?? 'English';
    final system =
        'You are Kisan Mitra, a friendly expert advisor for Indian small farmers. '
        'Answer ONLY in $langName. Maximum 80 words. Plain text only - no markdown symbols. '
        'Use very simple words an ordinary farmer understands. Give practical, low-cost advice suited to Indian conditions. '
        'For pesticide or fertilizer doses always give exact amounts (grams per litre, kg per acre). '
        'If the question is unclear, give the most likely useful answer for a farmer.';
    final user = '$context\n\nFarmer question: $question';

    final res = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            'X-Title': 'Kisan Mitra',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.4,
            'max_tokens': 256,
            'top_p': 0.9,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('or_${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('or_no_choices');
    }
    final content =
        ((choices.first as Map)['message'] as Map)['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('or_empty');
    }
    return content.trim();
  }

  void dispose() => _client.close();
}

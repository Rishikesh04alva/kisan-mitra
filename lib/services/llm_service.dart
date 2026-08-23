import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

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
    final prompt =
        'You are Kisan Mitra, a friendly expert advisor for Indian small farmers. '
        'Answer ONLY in $langName. Maximum 80 words. Plain text only — no markdown symbols. '
        'Use very simple words an ordinary farmer understands. Give practical, low-cost advice suited to Indian conditions. '
        'For pesticide or fertilizer doses always give exact amounts (grams per litre, kg per acre). '
        'If the question is unclear, give the most likely useful answer for a farmer.'
        '$context'
        '\n\nFarmer question: $question';

    final res = await _client
        .post(
          Uri.parse('$_endpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.4,
              'maxOutputTokens': 256,
              'topP': 0.9,
            },
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) {
      throw Exception('gemini_${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('gemini_no_candidates');
    }
    final parts =
        ((candidates.first as Map)['content'] as Map)['parts'] as List;
    return (parts.first as Map)['text'].toString().trim();
  }

  void dispose() => _client.close();
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Gemini-powered helpers for vendors (Phase 21).
///
/// The Gemini API key is read from Firestore (settings/ai -> geminiKey),
/// so the app owner can rotate it without shipping a new APK. Models are
/// tried in order so an alias/model retirement never breaks the feature.
class AiService {
  static const List<String> _models = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  /// Null when not configured — the UI hides the AI option in that case.
  Future<String?> apiKey() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('ai').get();
      final key = doc.data()?['geminiKey']?.toString() ?? '';
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  /// Writes a short marketplace-friendly product description.
  /// Returns null when AI isn't configured; throws a friendly message on
  /// API/rate-limit problems so the caller can surface it in a SnackBar.
  Future<String?> generateDescription({
    required String name,
    required String category,
    required String shopName,
  }) async {
    final key = await apiKey();
    if (key == null) return null;

    final prompt = 'You write product descriptions for GombeStore, a marketplace '
        'for shops in Gombe State, Nigeria. Write a short, warm product '
        'description of at most 40 words for this listing. '
        'Product name: "$name". Category: $category. Sold by: $shopName. '
        'Plain text only: no emojis, no markdown, no headings, no quotes. '
        'Mention value for money and mention delivery within Gombe State.';

    Object? lastError;
    for (final model in _models) {
      try {
        final res = await http
            .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': key,
              },
              body: jsonEncode({
                'contents': [
                  {'parts': [{'text': prompt}]}
                ],
                'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 200},
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final candidates = (body['candidates'] as List?) ?? const [];
          if (candidates.isEmpty) throw 'AI returned no text. Try again.';
          final content = (candidates.first as Map)['content'] as Map?;
          final parts = (content?['parts'] as List?) ?? const [];
          final text = parts.isEmpty ? '' : ((parts.first as Map)['text'] ?? '').toString();
          final cleaned = text.trim();
          if (cleaned.isEmpty) throw 'AI returned empty text. Try again.';
          return cleaned;
        }
        if (res.statusCode == 404 || res.statusCode == 400) {
          // Model name not available for this key -> try the next one.
          lastError = Exception('model unavailable');
          continue;
        }
        if (res.statusCode == 429) {
          throw 'AI rate limit reached — try again in a minute.';
        }
        throw 'AI error ${res.statusCode}. Check the geminiKey in settings/ai.';
      } catch (e) {
        if (e.toString().contains('rate limit')) rethrow;
        lastError = e;
      }
    }
    throw 'AI request failed: $lastError';
  }
}

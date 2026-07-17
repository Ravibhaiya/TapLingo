import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:taplingo/models/meaning_result.dart';

/// Gemini-only AI backend for word/sentence meanings (text + vision).
class GeminiService {
  static const modelName = 'gemini-2.0-flash';

  GenerativeModel _model(String apiKey) => GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          responseMimeType: 'application/json',
        ),
      );

  Future<MeaningResult> explainWord({
    required String apiKey,
    required String word,
    required String sentence,
  }) async {
    final prompt = '''
Explain the word "$word" as it's used in: "$sentence".
Use very simple, everyday words — explain it like you're talking to a 10-year-old.

Respond ONLY with valid JSON in this exact shape:
{
  "identifiedText": "$word",
  "plainMeaning": "plain dictionary-style meaning of the word",
  "contextualMeaning": "how the word is specifically being used in this sentence",
  "hinglish": "the word's meaning in Hinglish (mix of Hindi and English, casual and natural)",
  "example": "one short, simple example sentence using the word"
}
Keep every part short.
''';

    try {
      final response = await _model(apiKey).generateContent([Content.text(prompt)]);
      return _parse(response.text, taps: 2);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: 2);
    }
  }

  Future<MeaningResult> explainSentence({
    required String apiKey,
    required String sentence,
  }) async {
    final prompt = '''
Explain the full meaning of this sentence: "$sentence".
Use very simple, everyday words — explain it like you're talking to a 10-year-old.

Respond ONLY with valid JSON in this exact shape:
{
  "identifiedText": "the full sentence",
  "plainMeaning": "what the whole sentence means, in plain words",
  "hinglish": "the same sentence's meaning in Hinglish (mix of Hindi and English, casual and natural)"
}
Keep both parts short.
''';

    try {
      final response = await _model(apiKey).generateContent([Content.text(prompt)]);
      return _parse(response.text, taps: 3);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: 3);
    }
  }

  /// Manga: full page + crop + tap coordinate + tap count.
  Future<MeaningResult> explainMangaTap({
    required String apiKey,
    required Uint8List fullImageBytes,
    required Uint8List cropPng,
    required double x,
    required double y,
    required int taps,
  }) async {
    final isWord = taps == 2;
    final instruction = isWord
        ? '''
Here is a manga page and a cropped close-up. The user tapped at pixel ($x, $y) on the full image — the crop shows exactly what's there.
Identify the exact word/phrase at that tap point, then explain it simply enough for a kid to understand, using the surrounding dialogue in the full image for context.

Respond ONLY with valid JSON:
{
  "identifiedText": "the word or short phrase at the tap point",
  "plainMeaning": "plain meaning of that word/phrase",
  "contextualMeaning": "how it's used in the surrounding dialogue",
  "hinglish": "meaning in Hinglish (casual Hindi-English mix)",
  "example": "one short simple example sentence using the word"
}
Keep every part short.
'''
        : '''
Here is a manga page and a cropped close-up. The user tapped at pixel ($x, $y) on the full image.
First identify which full sentence or dialogue line that point belongs to (use the crop to pinpoint the exact spot, the full image for the rest of the line/bubble).
Then give the meaning of that whole sentence, simply enough for a kid to understand, and its meaning in Hinglish.

Respond ONLY with valid JSON:
{
  "identifiedText": "the full sentence or dialogue line",
  "plainMeaning": "what the whole sentence means, in plain words",
  "hinglish": "the sentence's meaning in Hinglish (casual Hindi-English mix)"
}
Keep both parts short.
''';

    try {
      final response = await _model(apiKey).generateContent([
        Content.multi([
          TextPart(instruction),
          DataPart(_mimeOf(fullImageBytes), fullImageBytes),
          TextPart(
            'Full manga page image above. Crop close-up of the tap region below:',
          ),
          DataPart('image/png', cropPng),
        ]),
      ]);
      return _parse(response.text, taps: taps);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: taps);
    }
  }

  String _mimeOf(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  MeaningResult _parse(String? text, {required int taps}) {
    if (text == null || text.trim().isEmpty) {
      return MeaningResult.error('Empty response from Gemini.', taps: taps);
    }
    try {
      var raw = text.trim();
      // Strip markdown fences if the model wraps JSON
      if (raw.startsWith('```')) {
        raw = raw.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
        raw = raw.replaceFirst(RegExp(r'\s*```$'), '');
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MeaningResult.fromJson(map, taps);
    } catch (_) {
      // Fallback: treat whole text as plain meaning
      return MeaningResult(
        taps: taps,
        plainMeaning: text.trim(),
        hinglish: '',
      );
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('API_KEY') || s.contains('api key') || s.contains('403')) {
      return 'Invalid Gemini API key. Check Settings.';
    }
    if (s.contains('429') || s.contains('quota') || s.contains('rate')) {
      return 'Gemini rate limit hit. Try again in a moment.';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'No internet connection.';
    }
    return 'Gemini error: ${s.length > 160 ? '${s.substring(0, 160)}…' : s}';
  }
}

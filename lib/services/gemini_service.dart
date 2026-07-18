import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:taplingo/models/meaning_result.dart';

/// Gemini AI backend for word/sentence meanings (text + vision).
/// Uses direct REST API calls for full control over thinkingConfig.
class GeminiService {
  static const modelName = 'gemini-3.1-flash-lite';
  static final _endpoint = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
  );

  /// Core method: sends parts to Gemini and returns the raw response map.
  Future<Map<String, dynamic>> _generate(
    String apiKey,
    List<Map<String, dynamic>> parts,
  ) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': parts,
        }
      ],
      'generationConfig': {
        'temperature': 0.0,
        'maxOutputTokens': 800,
        'responseMimeType': 'application/json',
        'thinkingConfig': {'thinkingLevel': 'NONE'},
      },
    });

    final response = await http.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Extracts the text content from a Gemini REST response.
  String? _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final content =
        candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    return parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
  }

  Future<MeaningResult> explainWord({
    required String apiKey,
    required String word,
    required String sentence,
  }) async {
    final prompt =
        'Word: "$word" in "$sentence". Fill JSON: '
        '{"identifiedText":"$word","plainMeaning":"simple meaning",'
        '"contextualMeaning":"meaning in this sentence",'
        '"hinglish":"Hindi-English meaning","example":"example sentence"}';

    try {
      final json = await _generate(apiKey, [
        {'text': prompt},
      ]);
      return _parse(_extractText(json), taps: 1);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: 1);
    }
  }

  Future<MeaningResult> explainSentence({
    required String apiKey,
    required String sentence,
  }) async {
    final prompt =
        'Sentence: "$sentence". Fill JSON: '
        '{"identifiedText":"the sentence","plainMeaning":"simple meaning",'
        '"hinglish":"Hindi-English meaning"}';

    try {
      final json = await _generate(apiKey, [
        {'text': prompt},
      ]);
      return _parse(_extractText(json), taps: 3);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: 3);
    }
  }

  /// Manga: full page + crop + tap coordinate + tap count.
  Future<MeaningResult> explainMangaTap({
    required String apiKey,
    required Uint8List fullImageBytes,
    required Uint8List cropPng,
    required int taps,
  }) async {
    final isWord = taps != 3;
    final instruction = isWord
        ? 'Image 1 is the full manga page. Use it for surrounding dialogue and story context.\n'
            'Image 2 is a close-up crop centered on the tapped area. A red dot in Image 2 marks exactly where the reader tapped.\n'
            'Identify the word under or closest to the red dot. Also, extract the full sentence or dialogue box the word is found in.\n'
            'Fill JSON: {"identifiedText":"word","sentenceContext":"full dialogue","plainMeaning":"simple meaning",'
            '"contextualMeaning":"meaning in dialogue",'
            '"hinglish":"Hindi-English meaning","example":"example sentence"}'
        : 'Image 1 is the full manga page. Use it for surrounding dialogue and story context.\n'
            'Image 2 is the exact cropped region selected by the user, containing a speech bubble or dialogue.\n'
            'Translate all dialogue in this region. Fill JSON: '
            '{"identifiedText":"the full dialogue","plainMeaning":"simple meaning",'
            '"hinglish":"Hindi-English meaning"}';

    try {
      final json = await _generate(apiKey, [
        {'text': instruction},
        {'text': 'Image 1 (Full page):'},
        {
          'inline_data': {
            'mime_type': _mimeOf(fullImageBytes),
            'data': base64Encode(fullImageBytes),
          }
        },
        {'text': 'Image 2 (Crop with red dot at tap):'},
        {
          'inline_data': {
            'mime_type': 'image/png',
            'data': base64Encode(cropPng),
          }
        },
      ]);
      return _parse(_extractText(json), taps: taps);
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
      raw = raw.trim();
      // Try to extract JSON if surrounded by other text
      final jsonMatch = RegExp(r'\{[^{}]*\}', dotAll: true).firstMatch(raw);
      if (jsonMatch != null) {
        raw = jsonMatch.group(0)!;
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

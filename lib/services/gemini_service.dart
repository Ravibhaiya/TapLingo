import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:taplingo/models/meaning_result.dart';
import 'package:taplingo/utils/image_crop.dart';

/// Gemini-only AI backend for word/sentence meanings (text + vision).
class GeminiService {
  static const modelName = 'gemini-3.1-flash-lite';

  @visibleForTesting
  MeaningResult parseExposed(String? text, {required int taps}) => _parse(text, taps: taps);

  static final _novelWordSchema = Schema.object(
    properties: {
      'identifiedText': Schema.string(),
      'plainMeaning': Schema.string(),
      'contextualMeaning': Schema.string(),
      'hinglish': Schema.string(),
      'example': Schema.string(),
    },
    requiredProperties: [
      'identifiedText',
      'plainMeaning',
      'contextualMeaning',
      'hinglish',
      'example',
    ],
  );

  static final _mangaWordSchema = Schema.object(
    properties: {
      'identifiedText': Schema.string(),
      'plainMeaning': Schema.string(),
      'contextualMeaning': Schema.string(),
      'sentenceContext': Schema.string(),
      'hinglish': Schema.string(),
      'example': Schema.string(),
    },
    requiredProperties: [
      'identifiedText',
      'plainMeaning',
      'contextualMeaning',
      'sentenceContext',
      'hinglish',
      'example',
    ],
  );

  static final _sentenceSchema = Schema.object(
    properties: {
      'identifiedText': Schema.string(),
      'plainMeaning': Schema.string(),
      'hinglish': Schema.string(),
    },
    requiredProperties: [
      'identifiedText',
      'plainMeaning',
      'hinglish',
    ],
  );

  GenerativeModel _model(String apiKey) => GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );

  Future<MeaningResult> explainWord({
    required String apiKey,
    required String word,
    required String sentence,
  }) async {
    final prompt =
        'Word: "$word" in "$sentence".\n'
        'Provide a JSON response. CRITICAL constraints:\n'
        '- identifiedText: the tapped word ("$word")\n'
        '- plainMeaning: a brief dictionary definition (maximum 15 words)\n'
        '- contextualMeaning: a brief explanation of what the word means in this specific sentence (maximum 15 words)\n'
        '- hinglish: a Hindi-English translation/explanation\n'
        '- example: a short example sentence using the word\n'
        'CRITICAL: Keep plainMeaning and contextualMeaning extremely short and concise. Do not repeat sentences.';

    try {
      final response = await _model(apiKey).generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 800,
          responseMimeType: 'application/json',
          responseSchema: _novelWordSchema,
        ),
      );
      return _parse(response.text, taps: 1);
    } catch (e) {
      return MeaningResult.error(_friendlyError(e), taps: 1);
    }
  }

  Future<MeaningResult> explainSentence({
    required String apiKey,
    required String sentence,
  }) async {
    final prompt =
        'Sentence: "$sentence".\n'
        'Provide a JSON response. CRITICAL constraints:\n'
        '- identifiedText: the sentence ("$sentence")\n'
        '- plainMeaning: a simple translation/explanation (maximum 20 words)\n'
        '- hinglish: a Hindi-English translation/explanation\n'
        'CRITICAL: Keep plainMeaning extremely short and concise. Do not repeat sentences.';

    try {
      final response = await _model(apiKey).generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 800,
          responseMimeType: 'application/json',
          responseSchema: _sentenceSchema,
        ),
      );
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
    required int taps,
  }) async {
    final isWord = taps != 3;
    final instruction = isWord
        ? 'Image 1 is the full manga page. Use it for surrounding dialogue and story context.\n'
            'Image 2 is a close-up crop centered on the tapped area. A red dot in Image 2 marks exactly where the reader tapped.\n'
            'Identify the word under or closest to the red dot. Also, extract the full sentence or dialogue box the word is found in.\n'
            'Provide a JSON response. CRITICAL constraints:\n'
            '- identifiedText: the word under the tap\n'
            '- sentenceContext: the full dialogue/sentence containing the word\n'
            '- plainMeaning: a brief dictionary definition (maximum 15 words)\n'
            '- contextualMeaning: a brief explanation of what the word means in this specific dialogue (maximum 15 words)\n'
            '- hinglish: a Hindi-English translation/explanation\n'
            '- example: a short example sentence using the word\n'
            'CRITICAL: Keep plainMeaning and contextualMeaning extremely short and concise. Do not repeat sentences.'
        : 'Image 1 is the full manga page. Use it for surrounding dialogue and story context.\n'
            'Image 2 is the exact cropped region selected by the user, containing a speech bubble or dialogue.\n'
            'Translate all dialogue in this region.\n'
            'Provide a JSON response. CRITICAL constraints:\n'
            '- identifiedText: the full dialogue/sentence\n'
            '- plainMeaning: a simple translation/explanation (maximum 20 words)\n'
            '- hinglish: a Hindi-English translation/explanation\n'
            'CRITICAL: Keep plainMeaning extremely short and concise. Do not repeat sentences.';

    try {
      final pageBytes = await downscaleImage(fullImageBytes, maxEdge: 1568);
      final response = await _model(apiKey).generateContent(
        [
          Content.multi([
            TextPart(instruction),
            TextPart('Image 1 (Full page):'),
            DataPart(_mimeOf(pageBytes), pageBytes),
            TextPart('Image 2 (Crop with red dot at tap):'),
            DataPart('image/png', cropPng),
          ]),
        ],
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 800,
          responseMimeType: 'application/json',
          responseSchema: isWord ? _mangaWordSchema : _sentenceSchema,
        ),
      );
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
      
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        raw = raw.substring(start, end + 1);
      }

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MeaningResult.fromJson(map, taps);
    } catch (e) {
      debugPrint('[GeminiService] Failed to parse JSON. Raw response: "$text"');
      debugPrint('[GeminiService] Parsing error: $e');
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

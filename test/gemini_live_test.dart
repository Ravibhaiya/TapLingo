import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/services/gemini_service.dart';

void main() {
  final service = GeminiService();
  String apiKey = '';

  setUpAll(() {
    try {
      final file = File('test/api_key.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        apiKey = map['key'] as String? ?? '';
      }
    } catch (e) {
      print('Could not load API key: $e');
    }
  });

  group('Live Gemini Integration Tests', () {
    test('explainWord returns proper JSON for single word', () async {
      if (apiKey.isEmpty) {
        markTestSkipped('No API key found in test/api_key.json');
        return;
      }

      final result = await service.explainWord(
        apiKey: apiKey,
        word: 'Ephemeral',
        sentence: 'The beauty of the cherry blossoms is highly ephemeral.',
      );

      expect(result.hasError, isFalse);
      expect(result.identifiedText?.toLowerCase(), contains('ephemeral'));
      expect(result.plainMeaning, isNotEmpty);
      expect(result.contextualMeaning, isNotEmpty);
      expect(result.hinglish, isNotEmpty);
      expect(result.example, isNotEmpty);
    });

    test('explainSentence returns proper JSON for sentence', () async {
      if (apiKey.isEmpty) {
        markTestSkipped('No API key found in test/api_key.json');
        return;
      }

      final result = await service.explainSentence(
        apiKey: apiKey,
        sentence: 'The early bird catches the worm.',
      );

      expect(result.hasError, isFalse);
      expect(result.plainMeaning, isNotEmpty);
      expect(result.hinglish, isNotEmpty);
      
      // Sentence schema doesn't have contextualMeaning or example fields
      expect(result.contextualMeaning, isNull);
      expect(result.example, isNull);
    });
  });
}

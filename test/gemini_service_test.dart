import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/services/gemini_service.dart';

void main() {
  final service = GeminiService();

  group('GeminiService JSON Parsing Tests', () {
    test('Parses a perfectly formatted Novel Word JSON', () {
      const responseText = '''
{
  "identifiedText": "numerous",
  "plainMeaning": "great in number; many",
  "contextualMeaning": "occurring in large numbers inside the text context",
  "hinglish": "Bahut saare ya sankhya mein adhik",
  "example": "There were numerous reasons for the delay."
}
''';
      final result = service.parseExposed(responseText, taps: 1);

      expect(result.hasError, isFalse);
      expect(result.identifiedText, 'numerous');
      expect(result.plainMeaning, 'great in number; many');
      expect(result.contextualMeaning, 'occurring in large numbers inside the text context');
      expect(result.hinglish, 'Bahut saare ya sankhya mein adhik');
      expect(result.example, 'There were numerous reasons for the delay.');
    });

    test('Parses JSON wrapped in markdown code fences', () {
      const responseText = '''
Here is the definition you requested:
```json
{
  "identifiedText": "abundant",
  "plainMeaning": "existing or available in large quantities",
  "contextualMeaning": "very plentiful in context",
  "hinglish": "Prachur matra mein",
  "example": "The area has abundant natural resources."
}
```
Hope this helps!
''';
      final result = service.parseExposed(responseText, taps: 1);

      expect(result.hasError, isFalse);
      expect(result.identifiedText, 'abundant');
      expect(result.plainMeaning, 'existing or available in large quantities');
      expect(result.hinglish, 'Prachur matra mein');
      expect(result.example, 'The area has abundant natural resources.');
    });

    test('Parses Sentence JSON successfully', () {
      const responseText = '''
{
  "identifiedText": "How are you?",
  "plainMeaning": "A common greeting asking about someone's well-being.",
  "hinglish": "Aap kaise hain?"
}
''';
      final result = service.parseExposed(responseText, taps: 3);

      expect(result.hasError, isFalse);
      expect(result.identifiedText, 'How are you?');
      expect(result.plainMeaning, "A common greeting asking about someone's well-being.");
      expect(result.hinglish, 'Aap kaise hain?');
    });

    test('Falls back gracefully to raw text when JSON is completely invalid', () {
      const responseText = 'This is not JSON at all, it is just a plain error response.';
      final result = service.parseExposed(responseText, taps: 1);

      expect(result.hasError, isFalse); // Falls back to treated plainMeaning instead of showing error UI
      expect(result.plainMeaning, responseText);
      expect(result.hinglish, '');
    });
  });
}

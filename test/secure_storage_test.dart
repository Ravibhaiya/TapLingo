import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureStorageService Tests', () {
    test('Stores API key trimmed and reads it back', () async {
      final service = SecureStorageService();

      expect(await service.hasGeminiApiKey(), isFalse);

      await service.setGeminiApiKey('  AIzaSyTestKey123  ');

      expect(await service.hasGeminiApiKey(), isTrue);
      expect(await service.getGeminiApiKey(), 'AIzaSyTestKey123');
    });

    test('Clears stored API key cleanly', () async {
      final service = SecureStorageService();

      await service.setGeminiApiKey('AIzaSyTestKey123');
      expect(await service.hasGeminiApiKey(), isTrue);

      await service.clearGeminiApiKey();

      expect(await service.hasGeminiApiKey(), isFalse);
      expect(await service.getGeminiApiKey(), isNull);
    });
  });
}

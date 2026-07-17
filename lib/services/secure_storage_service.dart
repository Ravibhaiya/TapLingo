import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the user's Gemini API key. Never hardcode keys.
class SecureStorageService {
  static const _geminiKey = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  Future<String?> getGeminiApiKey() => _storage.read(key: _geminiKey);

  Future<void> setGeminiApiKey(String key) =>
      _storage.write(key: _geminiKey, value: key.trim());

  Future<void> clearGeminiApiKey() => _storage.delete(key: _geminiKey);

  Future<bool> hasGeminiApiKey() async {
    final key = await getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }
}

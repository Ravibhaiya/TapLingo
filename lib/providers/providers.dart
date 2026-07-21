import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taplingo/models/library_item.dart';
import 'package:taplingo/services/gemini_service.dart';
import 'package:taplingo/services/library_storage.dart';
import 'package:taplingo/services/secure_storage_service.dart';
import 'package:taplingo/services/tts_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final libraryStorageProvider = Provider<LibraryStorage>((ref) {
  return LibraryStorage();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// User's Gemini API key from secure storage (null if unset).
final geminiApiKeyProvider =
    AsyncNotifierProvider<GeminiApiKeyNotifier, String?>(
  GeminiApiKeyNotifier.new,
);

class GeminiApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return ref.read(secureStorageProvider).getGeminiApiKey();
  }

  Future<void> setKey(String key) async {
    state = const AsyncLoading();
    try {
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        await ref.read(secureStorageProvider).clearGeminiApiKey();
        state = const AsyncData(null);
        return;
      }
      await ref.read(secureStorageProvider).setGeminiApiKey(trimmed);
      state = AsyncData(trimmed);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> clear() async {
    try {
      await ref.read(secureStorageProvider).clearGeminiApiKey();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const boxName = 'settings';
  static const key = 'theme_mode';

  Box get _box => Hive.box(boxName);

  @override
  ThemeMode build() {
    final raw = _box.get(key) as String?;
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setMode(ThemeMode mode) {
    state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    _box.put(key, value);
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, List<LibraryItem>>(LibraryNotifier.new);

class LibraryNotifier extends Notifier<List<LibraryItem>> {
  @override
  List<LibraryItem> build() {
    return ref.read(libraryStorageProvider).getAll();
  }

  void refresh() {
    state = ref.read(libraryStorageProvider).getAll();
  }

  Future<void> add(LibraryItem item) async {
    await ref.read(libraryStorageProvider).save(item);
    refresh();
  }

  Future<void> update(LibraryItem item) async {
    await ref.read(libraryStorageProvider).save(item);
    refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(libraryStorageProvider).delete(id);
    refresh();
  }

  Future<void> updateProgress({
    required String id,
    String? lastReadUrl,
    double? lastReadPosition,
  }) async {
    await ref.read(libraryStorageProvider).updateProgress(
          id: id,
          lastReadUrl: lastReadUrl,
          lastReadPosition: lastReadPosition,
        );
    refresh();
  }

  List<LibraryItem> byType(LibraryType type) =>
      state.where((e) => e.type == type).toList();
}

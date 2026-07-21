import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/models/library_item.dart';

void main() {
  group('LibraryItem Model Tests', () {
    test('Serializes to JSON and deserializes from JSON accurately', () {
      final now = DateTime.now();
      final item = LibraryItem(
        id: 'test-123',
        name: 'The Beginning After The End',
        type: LibraryType.novel,
        url: 'https://example.com/novel/ch1',
        dateAdded: now,
        lastReadUrl: 'https://example.com/novel/ch5',
        lastReadPosition: 1250.5,
        lastOpenedAt: now,
      );

      final json = item.toJson();
      final restored = LibraryItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.type, LibraryType.novel);
      expect(restored.url, item.url);
      expect(restored.dateAdded.toIso8601String(), item.dateAdded.toIso8601String());
      expect(restored.lastReadUrl, item.lastReadUrl);
      expect(restored.lastReadPosition, item.lastReadPosition);
      expect(restored.lastOpenedAt?.toIso8601String(), item.lastOpenedAt?.toIso8601String());
    });

    test('Falls back to default url if lastReadUrl is missing in JSON', () {
      final now = DateTime.now();
      final json = {
        'id': 'manga-456',
        'name': 'Solo Leveling',
        'type': 'manga',
        'url': 'https://example.com/manga/ch10',
        'dateAdded': now.toIso8601String(),
      };

      final item = LibraryItem.fromJson(json);

      expect(item.id, 'manga-456');
      expect(item.type, LibraryType.manga);
      expect(item.lastReadUrl, 'https://example.com/manga/ch10');
      expect(item.lastReadPosition, 0.0);
      expect(item.lastOpenedAt, isNull);
    });

    test('Falls back to LibraryType.novel when type string is unknown', () {
      final json = {
        'id': 'unknown-789',
        'name': 'Unknown Story',
        'type': 'unknown_type_value',
        'url': 'https://example.com/story',
        'dateAdded': DateTime.now().toIso8601String(),
      };

      final item = LibraryItem.fromJson(json);

      expect(item.type, LibraryType.novel);
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime.now();
      final original = LibraryItem(
        id: '1',
        name: 'Original Title',
        type: LibraryType.novel,
        url: 'https://example.com/1',
        dateAdded: now,
        lastReadUrl: 'https://example.com/1',
        lastReadPosition: 100.0,
      );

      final updated = original.copyWith(
        name: 'Updated Title',
        lastReadPosition: 550.0,
      );

      expect(updated.id, original.id);
      expect(updated.name, 'Updated Title');
      expect(updated.lastReadPosition, 550.0);
      expect(updated.url, original.url);
    });
  });
}

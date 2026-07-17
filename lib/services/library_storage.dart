import 'package:hive_flutter/hive_flutter.dart';
import 'package:taplingo/models/library_item.dart';

class LibraryStorage {
  static const boxName = 'library';

  Box get _box => Hive.box(boxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  List<LibraryItem> getAll() {
    return _box.values
        .map((e) => LibraryItem.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.dateAdded;
        final bTime = b.lastOpenedAt ?? b.dateAdded;
        return bTime.compareTo(aTime);
      });
  }

  List<LibraryItem> getByType(LibraryType type) =>
      getAll().where((e) => e.type == type).toList();

  LibraryItem? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return LibraryItem.fromJson(Map<dynamic, dynamic>.from(raw as Map));
  }

  Future<void> save(LibraryItem item) async {
    await _box.put(item.id, item.toJson());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> updateProgress({
    required String id,
    String? lastReadUrl,
    double? lastReadPosition,
  }) async {
    final existing = getById(id);
    if (existing == null) return;
    await save(
      existing.copyWith(
        lastReadUrl: lastReadUrl,
        lastReadPosition: lastReadPosition,
        lastOpenedAt: DateTime.now(),
      ),
    );
  }
}

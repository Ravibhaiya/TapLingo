import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/models/library_item.dart';
import 'package:taplingo/providers/providers.dart';
import 'package:taplingo/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createHomeScreen(List<LibraryItem> initialItems) {
    return ProviderScope(
      overrides: [
        libraryProvider.overrideWith(() => MockLibraryNotifier(initialItems)),
        geminiApiKeyProvider.overrideWith(() => MockGeminiApiKeyNotifier()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Widget Tests', () {
    testWidgets('Renders empty states when library is empty', (tester) async {
      await tester.pumpWidget(createHomeScreen([]));
      await tester.pumpAndSettle();

      expect(find.text('No novels yet'), findsOneWidget);
      expect(find.text('TapLingo'), findsOneWidget);

      // Switch to Manga tab
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      expect(find.text('No manga yet'), findsOneWidget);
    });

    testWidgets('Displays novel and manga items in their respective tabs', (tester) async {
      final novel = LibraryItem(
        id: 'n1',
        name: 'The Overlord Novel',
        type: LibraryType.novel,
        url: 'https://example.com/novel',
        dateAdded: DateTime.now(),
        lastReadUrl: 'https://example.com/novel',
      );

      final manga = LibraryItem(
        id: 'm1',
        name: 'Chainsaw Man',
        type: LibraryType.manga,
        url: 'https://example.com/manga',
        dateAdded: DateTime.now(),
        lastReadUrl: 'https://example.com/manga',
      );

      await tester.pumpWidget(createHomeScreen([novel, manga]));
      await tester.pumpAndSettle();

      // Novel tab should display 'The Overlord Novel'
      expect(find.text('The Overlord Novel'), findsOneWidget);
      expect(find.text('Chainsaw Man'), findsNothing);

      // Switch to Manga tab
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      // Manga tab should display 'Chainsaw Man'
      expect(find.text('Chainsaw Man'), findsOneWidget);
    });
  });
}

class MockLibraryNotifier extends LibraryNotifier {
  final List<LibraryItem> _initial;
  MockLibraryNotifier(this._initial);

  @override
  List<LibraryItem> build() => _initial;
}

class MockGeminiApiKeyNotifier extends GeminiApiKeyNotifier {
  @override
  Future<String?> build() async => 'mock-api-key-12345';
}

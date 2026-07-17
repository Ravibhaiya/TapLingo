import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taplingo/main.dart';
import 'package:taplingo/services/library_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    await Hive.openBox(LibraryStorage.boxName);
    await Hive.openBox('settings');
  });

  testWidgets('TapLingo app builds home shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TapLingoApp()));
    await tester.pump();

    // Home title
    expect(find.text('TapLingo'), findsOneWidget);
    // Top tabs
    expect(find.text('Novel'), findsOneWidget);
    expect(find.text('Manga'), findsOneWidget);
  });
}

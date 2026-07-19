import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/models/meaning_result.dart';
import 'package:taplingo/widgets/meaning_bottom_sheet.dart';

void main() {
  Widget createTestWidget(Future<MeaningResult> loadFuture, int taps) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showMeaningBottomSheet(
                    context: context,
                    taps: taps,
                    load: () => loadFuture,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('Renders all fields for word meaning (taps=1)', (tester) async {
    final mockResult = MeaningResult(
      identifiedText: 'ephemeral',
      plainMeaning: 'lasting for a very short time',
      contextualMeaning: 'short-lived in this text',
      hinglish: 'kshanik ya thodi der ka',
      example: 'Fashions are ephemeral.',
      taps: 1,
    );

    await tester.pumpWidget(createTestWidget(Future.value(mockResult), 1));
    await tester.pumpAndSettle();

    // Tap button to open bottom sheet
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle(); // Wait for animation

    expect(find.text('ephemeral', skipOffstage: false), findsOneWidget);
    expect(find.text('lasting for a very short time', skipOffstage: false), findsOneWidget);
    expect(find.text('short-lived in this text', skipOffstage: false), findsOneWidget);
    expect(find.text('Meaning in Hinglish', skipOffstage: false), findsOneWidget);
    expect(find.text('kshanik ya thodi der ka', skipOffstage: false), findsOneWidget);
    expect(find.text('Example', skipOffstage: false), findsOneWidget);
    expect(find.text('Fashions are ephemeral.', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Does not render missing fields for sentences (taps=3)', (tester) async {
    final mockResult = MeaningResult(
      identifiedText: 'How are you?',
      plainMeaning: 'Greeting',
      contextualMeaning: '', // Sentences do not have this
      hinglish: 'Aap kaise hain?',
      example: '', // Sentences do not have examples
      taps: 3,
    );

    await tester.pumpWidget(createTestWidget(Future.value(mockResult), 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('How are you?', skipOffstage: false), findsOneWidget);
    expect(find.text('Greeting', skipOffstage: false), findsOneWidget);
    expect(find.text('Meaning in Hinglish', skipOffstage: false), findsOneWidget);
    expect(find.text('Aap kaise hain?', skipOffstage: false), findsOneWidget);

    // Contextual meaning and examples should not exist
    expect(find.text('Example', skipOffstage: false), findsNothing);
  });

  testWidgets('Renders error UI when result has error', (tester) async {
    final mockResult = MeaningResult.error('Failed to parse Gemini output', taps: 1);

    await tester.pumpWidget(createTestWidget(Future.value(mockResult), 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Failed to parse Gemini output'), findsOneWidget);
  });
}

import 'package:driftid_ui/models/history_entry.dart';
import 'package:driftid_ui/models/prediction.dart';
import 'package:driftid_ui/screens/history_screen.dart';
import 'package:driftid_ui/screens/result_screen.dart';
import 'package:driftid_ui/services/history_store.dart';
import 'package:driftid_ui/services/result_controller.dart';
import 'package:driftid_ui/widgets/prediction_list.dart';
import 'package:driftid_ui/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  HistoryEntry entry() => HistoryEntry(
        id: 'e1',
        createdAt: DateTime(2026, 6, 1),
        source: HistorySource.url,
        imageRef: 'https://example.com/e1.jpg',
        predictions: const [
          Prediction(className: 'audi_a7-gen_2010_2014', confidence: 0.9),
          Prediction(className: 'bmw_m3', confidence: 0.05),
          Prediction(className: 'tesla_model-s', confidence: 0.02),
        ],
      );

  testWidgets('empty controller shows the Result empty state, not a result',
      (tester) async {
    final controller = ResultController();
    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(controller: controller)),
    );

    expect(find.byKey(const Key('result-empty')), findsOneWidget);
    expect(find.byKey(const Key('result-screen')), findsNothing);
    expect(find.byType(ResultView), findsNothing);
    expect(find.text('No result yet'), findsOneWidget);
  });

  testWidgets('publishing a result swaps the empty state for the ResultView',
      (tester) async {
    final controller = ResultController();
    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(controller: controller)),
    );

    controller.show(
      url: 'https://example.com/fresh.jpg',
      predictions: const [
        Prediction(className: 'audi_a7-gen_2010_2014', confidence: 0.9),
      ],
    );
    await tester.pump();

    expect(find.byKey(const Key('result-empty')), findsNothing);
    expect(find.byKey(const Key('result-screen')), findsOneWidget);
    expect(find.byType(ResultView), findsOneWidget);
    expect(find.byType(PredictionList), findsOneWidget);
    // A fresh result carries no saved badge.
    expect(find.byKey(const Key('saved-result')), findsNothing);
    expect(find.text('Audi A7'), findsOneWidget);
  });

  testWidgets('a reopened saved result renders full top-k with a saved marker',
      (tester) async {
    final controller = ResultController();
    final e = entry();
    controller.show(
      bytes: e.imageBytes,
      url: e.imageUrl,
      predictions: e.predictions,
      saved: true,
      savedAt: e.createdAt,
    );

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(controller: controller)),
    );

    expect(find.byType(ResultView), findsOneWidget);
    expect(find.byKey(const Key('top-prediction')), findsOneWidget);
    expect(find.text('Best match'), findsOneWidget);
    // Full top-k carries over: top match + the two runner-up rows.
    expect(find.text('Audi A7'), findsOneWidget);
    expect(find.text('Bmw M3'), findsOneWidget);
    expect(find.text('Tesla Model S'), findsOneWidget);
    // Clearly marked as a saved/past result (US-10).
    expect(find.byKey(const Key('saved-result')), findsOneWidget);
  });

  testWidgets('tapping a History tile publishes the saved result + reopens',
      (tester) async {
    final store = HistoryStore();
    await store.load();
    await store.add(entry());

    final controller = ResultController();
    var reopened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          historyStore: store,
          resultController: controller,
          onReopen: () => reopened = true,
        ),
      ),
    );

    expect(find.byKey(const Key('history-tile-e1')), findsOneWidget);
    expect(controller.hasResult, isFalse);

    await tester.tap(find.byKey(const Key('history-tile-e1')));
    await tester.pumpAndSettle();

    // Reopen publishes a saved result (no API call) and asks to switch tabs.
    expect(reopened, isTrue);
    expect(controller.hasResult, isTrue);
    expect(controller.current!.saved, isTrue);
    expect(controller.current!.predictions.length, 3);
  });
}

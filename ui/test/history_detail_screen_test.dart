import 'package:driftid_ui/models/history_entry.dart';
import 'package:driftid_ui/models/prediction.dart';
import 'package:driftid_ui/screens/history_detail_screen.dart';
import 'package:driftid_ui/screens/history_screen.dart';
import 'package:driftid_ui/services/history_store.dart';
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

  testWidgets('detail screen shows the full top-k and a saved marker',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HistoryDetailScreen(entry: entry())),
    );

    // Same result presentation as a fresh identification (US-10).
    expect(find.byType(ResultView), findsOneWidget);
    expect(find.byType(PredictionList), findsOneWidget);
    expect(find.byKey(const Key('top-prediction')), findsOneWidget);
    expect(find.text('Best match'), findsOneWidget);

    // Full top-k carries over: top match + the two runner-up rows.
    expect(find.text('Audi A7'), findsOneWidget);
    expect(find.text('Bmw M3'), findsOneWidget);
    expect(find.text('Tesla Model S'), findsOneWidget);

    // Clearly marked as a saved/past result (US-10).
    expect(find.byKey(const Key('saved-result')), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Saved result'), findsOneWidget);
  });

  testWidgets('tapping a history tile reopens the saved result', (tester) async {
    final store = HistoryStore();
    await store.load();
    await store.add(entry());

    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(historyStore: store)),
    );

    expect(find.byKey(const Key('history-tile-e1')), findsOneWidget);
    expect(find.byType(HistoryDetailScreen), findsNothing);

    await tester.tap(find.byKey(const Key('history-tile-e1')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('saved-result')), findsOneWidget);
    expect(find.text('Best match'), findsOneWidget);
  });
}

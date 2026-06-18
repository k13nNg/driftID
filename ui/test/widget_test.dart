import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftid_ui/main.dart';
import 'package:driftid_ui/screens/home_screen.dart';

void main() {
  testWidgets('Search shows the image card, URL field, and Identify only',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DriftIDApp());

    expect(find.text('DriftID'), findsOneWidget);
    // Decluttered Search (T015/US-13): single image card + URL field + Identify.
    expect(find.byKey(const Key('image-card')), findsOneWidget);
    expect(find.byKey(const Key('url-field')), findsOneWidget);
    expect(find.byKey(const Key('identify-button')), findsOneWidget);

    // No tagline header and no separate upload button on Search anymore.
    expect(find.text(kAppTagline), findsNothing);
    expect(find.text('Upload image'), findsNothing);
  });
}

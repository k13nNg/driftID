import 'package:flutter_test/flutter_test.dart';

import 'package:driftid_ui/main.dart';
import 'package:driftid_ui/screens/home_screen.dart';

void main() {
  testWidgets('home screen shows the DriftID summary and controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DriftIDApp());

    expect(find.text('DriftID'), findsOneWidget);
    expect(find.text(kAppTagline), findsOneWidget);
    expect(find.text('Upload image'), findsOneWidget);
    expect(find.text('Identify'), findsOneWidget);
  });
}

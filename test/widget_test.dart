import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shows the speech helper title', (WidgetTester tester) async {
    await tester.pumpWidget(const SpeechHelperApp());

    expect(find.text('語音小幫手'), findsOneWidget);
    expect(find.text('辨識語言'), findsOneWidget);
  });
}

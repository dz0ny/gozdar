import 'package:flutter_test/flutter_test.dart';

import 'package:gozdar/main.dart';

void main() {
  testWidgets('App builds and shows navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(const GozdarApp());

    // Verify that navigation tabs are present
    expect(find.text('Karta'), findsOneWidget);
    expect(find.text('Hlodi'), findsOneWidget);
  });
}

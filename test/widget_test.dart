import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gozdar/main.dart';
import 'package:gozdar/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_version': OnboardingService.currentVersion,
    });
    await OnboardingService.initialize();
  });

  testWidgets('App builds and shows navigation bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GozdarApp()));
    await tester.pumpAndSettle();

    // Verify that navigation tabs are present
    expect(find.text('Karta'), findsOneWidget);
    expect(find.text('Hlodi'), findsOneWidget);
  });
}

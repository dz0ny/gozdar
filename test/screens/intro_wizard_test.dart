import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/screens/intro_wizard_screen.dart';
import 'package:gozdar/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('wizardPagesFor', () {
    test('a new install sees every page, terms last', () {
      final pages = wizardPagesFor(0);
      expect(pages.first, WizardPage.welcome);
      expect(pages.last, WizardPage.terms);
      expect(pages, contains(WizardPage.secnja));
      expect(pages.length, WizardPage.values.length);
    });

    test('an install that finished version 3 sees only the new pages', () {
      expect(wizardPagesFor(3), [WizardPage.secnja]);
    });

    test('an install on the current version sees nothing', () {
      expect(wizardPagesFor(OnboardingService.currentVersion), isEmpty);
    });
  });

  Future<GoRouter> pumpWizard(
    WidgetTester tester, {
    required int completed,
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_version': completed});
    await OnboardingService.initialize();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const IntroWizardScreen(),
        ),
        GoRoute(
          path: '/forest',
          builder: (_, _) => const Scaffold(body: Text('FOREST')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('existing install: one page about sečnja, then done', (
    tester,
  ) async {
    await pumpWizard(tester, completed: 3);
    expect(find.text('Sečnja za sekača'), findsOneWidget);
    expect(find.text('Preskoči').hitTestable(), findsNothing);
    await tester.tap(find.text('Začni'));
    await tester.pumpAndSettle();
    expect(find.text('FOREST'), findsOneWidget);
    expect(OnboardingService.instance.isOnboardingCompleted, isTrue);
  });
}

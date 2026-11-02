import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:gozdar/router/app_router.dart';
import 'package:gozdar/services/onboarding_service.dart';
import 'package:gozdar/services/secnja_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeShareService extends SecnjaShareService {
  FakeShareService(this.outcome);

  final ReceiveOutcome outcome;
  final received = <String>[];

  @override
  Future<ReceiveOutcome> receive(String shareId) async {
    received.add(shareId);
    if (outcome == ReceiveOutcome.imported) {
      lastReceived = SecnjaSharePayload(
        parcelNumber: '1234/5',
        points: [SecnjaPoint(name: 'Drevo 1', lat: 46, lng: 14)],
        createdAt: DateTime.utc(2026, 11, 2),
      );
    }
    return outcome;
  }
}

GoRouter router(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        receiveShareRoute(),
        GoRoute(path: '/map', builder: (_, _) => const Scaffold(body: Text('MAP'))),
        GoRoute(path: '/forest', builder: (_, _) => const Scaffold(body: Text('FOREST'))),
        GoRoute(path: '/onboarding', builder: (_, _) => const Scaffold(body: Text('ONBOARDING'))),
      ],
    );

Widget app(GoRouter r) => MaterialApp.router(
      routerConfig: r,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sl'),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_version': OnboardingService.currentVersion});
    await OnboardingService.initialize();
  });

  testWidgets('cold start on /s/:id calls receive with the id and lands on the map',
      (tester) async {
    final fake = FakeShareService(ReceiveOutcome.imported);
    SecnjaShareService.instance = fake;
    await tester.pumpWidget(app(router('/s/abc123')));
    await tester.pumpAndSettle();
    expect(fake.received, ['abc123']);
    expect(find.text('MAP'), findsOneWidget);
    expect(find.textContaining('Prejeta sečnja: parcela 1234/5'), findsOneWidget);
  });

  testWidgets('warm start: go(/s/xyz) from another screen calls receive', (tester) async {
    final fake = FakeShareService(ReceiveOutcome.imported);
    SecnjaShareService.instance = fake;
    final r = router('/forest');
    await tester.pumpWidget(app(r));
    await tester.pumpAndSettle();
    expect(find.text('FOREST'), findsOneWidget);
    r.go('/s/xyz');
    await tester.pumpAndSettle();
    expect(fake.received, ['xyz']);
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('expired outcome shows the expired snackbar', (tester) async {
    SecnjaShareService.instance = FakeShareService(ReceiveOutcome.expired);
    await tester.pumpWidget(app(router('/s/old')));
    await tester.pumpAndSettle();
    expect(find.text('Povezava je potekla ali bila preklicana'), findsOneWidget);
  });
}

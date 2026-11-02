import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gozdar/models/navigation_target.dart';
import 'package:gozdar/router/navigation_notifier.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

void main() {
  final target = NavigationTarget(
    location: const LatLng(46, 14),
    name: 'Smreka 1',
  );

  Widget detail(NavigationNotifier notifier) => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => goToMapWithTarget(context, target),
        child: const Text('NAVIGATE'),
      ),
    ),
  );

  Future<NavigationNotifier> pump(
    WidgetTester tester, {
    required bool pushed,
  }) async {
    final notifier = NavigationNotifier();
    final router = GoRouter(
      initialLocation: pushed ? '/map' : '/forest/parcel',
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => detail(notifier))),
              child: const Text('MAP'),
            ),
          ),
        ),
        GoRoute(path: '/forest/parcel', builder: (_, _) => detail(notifier)),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('MAP'));
      await tester.pumpAndSettle();
    }
    return notifier;
  }

  testWidgets('from a parcel pushed over the map, it closes the parcel', (
    tester,
  ) async {
    final notifier = await pump(tester, pushed: true);
    await tester.tap(find.text('NAVIGATE'));
    await tester.pumpAndSettle();
    expect(find.text('NAVIGATE'), findsNothing);
    expect(find.text('MAP'), findsOneWidget);
    expect(notifier.pendingNavigationTarget, target);
  });

  testWidgets('from a parcel route, it goes to the map', (tester) async {
    final notifier = await pump(tester, pushed: false);
    await tester.tap(find.text('NAVIGATE'));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
    expect(notifier.pendingNavigationTarget, target);
  });
}

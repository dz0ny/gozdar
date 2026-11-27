import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gozdar/models/navigation_target.dart';
import 'package:gozdar/router/navigation_notifier.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final target = NavigationTarget(
    location: const LatLng(46, 14),
    name: 'Smreka 1',
  );

  Widget detail() => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => goToMapWithTarget(context, target),
        child: const Text('NAVIGATE'),
      ),
    ),
  );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool pushed,
  }) async {
    final container = ProviderContainer.test();
    final router = GoRouter(
      initialLocation: pushed ? '/map' : '/forest/parcel',
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => detail())),
              child: const Text('MAP'),
            ),
          ),
        ),
        GoRoute(path: '/forest/parcel', builder: (_, _) => detail()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('MAP'));
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('from a parcel pushed over the map, it closes the parcel', (
    tester,
  ) async {
    final container = await pump(tester, pushed: true);
    await tester.tap(find.text('NAVIGATE'));
    await tester.pumpAndSettle();
    expect(find.text('NAVIGATE'), findsNothing);
    expect(find.text('MAP'), findsOneWidget);
    expect(
      container.read(navigationNotifierProvider).pendingNavigationTarget,
      target,
    );
  });

  testWidgets('from a parcel route, it goes to the map', (tester) async {
    final container = await pump(tester, pushed: false);
    await tester.tap(find.text('NAVIGATE'));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
    expect(
      container.read(navigationNotifierProvider).pendingNavigationTarget,
      target,
    );
  });
}

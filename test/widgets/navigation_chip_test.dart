import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/navigation_target.dart';
import 'package:gozdar/widgets/location_tracker.dart';
import 'package:gozdar/widgets/navigation_chip.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const target = NavigationTarget(location: LatLng(46.002, 14), name: 'Hrast');

  Future<({ValueNotifier<UserFix?> fix, List<String> calls})> pump(
    WidgetTester tester,
  ) async {
    final fix = ValueNotifier<UserFix?>(null);
    addTearDown(fix.dispose);
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Center(
            child: NavigationChip(
              target: target,
              fix: fix,
              onOpenCompass: () => calls.add('compass'),
              onEnd: () => calls.add('end'),
            ),
          ),
        ),
      ),
    );
    return (fix: fix, calls: calls);
  }

  testWidgets('shows the target, and the distance once there is a fix', (
    tester,
  ) async {
    final (:fix, calls: _) = await pump(tester);
    expect(find.text('Hrast'), findsOneWidget);
    expect(find.textContaining(' m'), findsNothing);

    fix.value = const UserFix(LatLng(46, 14), null);
    await tester.pump();
    // 0.002° of latitude is about 222 m.
    expect(find.text(' · 222 m'), findsOneWidget);

    fix.value = const UserFix(LatLng(46.001, 14), null);
    await tester.pump();
    expect(find.text(' · 111 m'), findsOneWidget);
  });

  testWidgets('tap opens the compass, the ✕ ends navigation', (tester) async {
    final (fix: _, :calls) = await pump(tester);

    await tester.tap(find.text('Hrast'));
    await tester.tap(find.byTooltip('Končaj navigacijo'));

    expect(calls, ['compass', 'end']);
  });
}

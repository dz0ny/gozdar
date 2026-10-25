import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/map_layer.dart';
import 'package:gozdar/widgets/map_controls.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('status column clears map controls at $size', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sl'),
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.grey)),
                Positioned(
                  top: 16,
                  left: 16,
                  right: MapControls.reservedRightInset,
                  child: Container(
                    key: const Key('status'),
                    height: 200,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            floatingActionButton: MapControls(
              mapController: MapController(),
              currentBaseLayer: MapLayer.baseLayers.first,
              locationsCount: 0,
              onLayerSelectorPressed: () {},
              onGpsPressed: () {},
              onSearchPressed: () {},
            ),
          ),
        ),
      );
      final status = tester.getRect(find.byKey(const Key('status')));
      for (final fab in tester.widgetList(find.byType(FloatingActionButton))) {
        final r = tester.getRect(find.byWidget(fab));
        expect(
          r.overlaps(status),
          isFalse,
          reason: '${(fab as FloatingActionButton).tooltip}',
        );
      }
    });
  }
}

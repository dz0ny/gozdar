import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/cadastral_service.dart';
import 'package:gozdar/widgets/parcel_found_sheet.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const parcel = WfsParcel(
    localId: 'SI.GURS.KN.1651.1092',
    label: '1092',
    nationalCadastralReference: '1651 1092',
    area: 1924,
    polygon: [LatLng(46, 14), LatLng(46, 14.001), LatLng(46.001, 14.001)],
  );

  testWidgets('shows only details, keeps the map tappable, one action',
      (tester) async {
    final key = GlobalKey<ScaffoldState>();
    var hidden = 0, acted = 0;
    var mapTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: key,
        body: GestureDetector(
          key: const Key('map'),
          behavior: HitTestBehavior.opaque,
          onTap: () => mapTaps++,
        ),
      ),
    ));
    final controller = ParcelFoundSheet.show(
      scaffold: key.currentState!,
      wfsParcel: parcel,
      existingParcel: null,
      onHide: () => hidden++,
      onAction: () => acted++,
    );
    await tester.pumpAndSettle();

    expect(find.text('Parcela 1092'), findsOneWidget);
    expect(find.text('Parcela najdena'), findsNothing);
    expect(find.byType(ModalBarrier).evaluate().where(
        (e) => (e.widget as ModalBarrier).dismissible), isEmpty);

    // The map above the sheet still receives taps (no backdrop).
    await tester.tapAt(const Offset(400, 40));
    expect(mapTaps, 1);

    await tester.tap(find.text('Uvozi parcelo'));
    await tester.pumpAndSettle();
    expect(acted, 1);
    expect(find.text('Parcela 1092'), findsNothing);
    await controller.closed;

    ParcelFoundSheet.show(
      scaffold: key.currentState!,
      wfsParcel: parcel,
      existingParcel: null,
      onHide: () => hidden++,
      onAction: () {},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skrij'));
    await tester.pumpAndSettle();
    expect(hidden, 1);
  });
}

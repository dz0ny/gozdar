import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/map_long_press_menu.dart';

void main() {
  testWidgets('Navigiraj is a top-level action that closes the sheet first',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapLongPressMenu(
          onAddLocation: () {},
          onAddLog: () {},
          onAddSecnja: () {},
          onImportParcel: () {},
          onNavigate: () => calls.add('navigate'),
          onMeasureDistance: () {},
          onMeasureArea: () {},
          mejnikiAvailable: false,
          showMejniki: false,
          onToggleMejniki: (_) {},
          onClose: () => calls.add('close'),
        ),
      ),
    ));
    expect(find.text('Navigiraj'), findsOneWidget);
    await tester.tap(find.text('Navigiraj'));
    await tester.pump();
    expect(calls, ['close', 'navigate']);
  });
}

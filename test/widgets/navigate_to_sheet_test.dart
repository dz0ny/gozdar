import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/navigate_to_sheet.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final babnoPolje = LatLng(45.645863, 14.549296);

  test('Google Maps: turn-by-turn scheme first on Android, https fallback last',
      () {
    final android = NavigateToSheet.googleMapsUris(babnoPolje,
        platform: TargetPlatform.android);
    expect(android.first.toString(), 'google.navigation:q=45.645863,14.549296');
    expect(android.last.host, 'www.google.com');
    expect(android.last.queryParameters['destination'], '45.645863,14.549296');

    final ios = NavigateToSheet.googleMapsUris(babnoPolje,
        platform: TargetPlatform.iOS);
    expect(ios.first.scheme, 'comgooglemaps');
    expect(ios.first.queryParameters['daddr'], '45.645863,14.549296');
  });

  test('Apple Maps URL carries the destination', () {
    final uri = NavigateToSheet.appleMapsUri(babnoPolje);
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['daddr'], '45.645863,14.549296');
  });

  test('coordinates use the "lat, lon" clipboard format', () {
    expect(NavigateToSheet.coordinates(babnoPolje), '45.645863, 14.549296');
  });

  testWidgets('sheet lists the options and the compass option calls back',
      (tester) async {
    var inApp = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => NavigateToSheet.show(
              context,
              destination: babnoPolje,
              name: 'Parc. 1007/3',
              onInAppNavigation: () => inApp++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Parc. 1007/3'), findsOneWidget);
    expect(find.text('Google Zemljevidi'), findsOneWidget);
    expect(find.text('Kompas v aplikaciji'), findsOneWidget);
    expect(find.text('Kopiraj koordinate'), findsOneWidget);

    await tester.tap(find.text('Kompas v aplikaciji'));
    await tester.pumpAndSettle();
    expect(inApp, 1);
    expect(find.text('Google Zemljevidi'), findsNothing); // sheet closed
  });
}

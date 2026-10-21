// Renders the owner-search UI to PNGs in test/screenshots/out for visual
// review. Not a regression test, so it is skipped unless given an owners
// database and the SDK's material fonts directory:
//
//   flutter test --update-goldens test/screenshots \
//     --dart-define=OWNERS_DB=/path/to/owners.sqlite \
//     --dart-define=MATERIAL_FONTS=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:gozdar/theme/app_theme.dart';
import 'package:gozdar/widgets/parcel_search_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _db = String.fromEnvironment('OWNERS_DB');
const _fonts = String.fromEnvironment('MATERIAL_FONTS');

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    await loader.load();
  }

  await load('Roboto', 'assets/fonts/Roboto-Regular.ttf');
  await load('MaterialIcons', '$_fonts/MaterialIcons-Regular.otf');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_db.isEmpty || _fonts.isEmpty) return;

  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    OwnerLookupService.instance.openForTesting(_db);
  });

  Future<void> phone(WidgetTester tester, {double keyboard = 0}) async {
    // Keep rendering through layout errors so they show up in the PNG.
    final original = FlutterError.onError;
    FlutterError.onError = (d) => debugPrint('LAYOUT: ${d.exceptionAsString().split('\n').first}');
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
  }

  for (final keyboard in [0.0, 300.0]) {
    testWidgets('search dialog owner tab (keyboard $keyboard)', (tester) async {
      await phone(tester, keyboard: keyboard);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.greenTheme,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => ParcelSearchDialog.show(
                  context: context,
                  mapController: MapController(),
                  onParcelFound: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nov');
      await tester.pump(const Duration(milliseconds: 400));
      // The search runs on a real background isolate.
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/dialog_owner_kb${keyboard.toInt()}.png'),
      );
    });
  }
}

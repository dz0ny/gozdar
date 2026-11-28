import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/map_camera_animator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late MapController controller;
  late MapCameraAnimator animator;

  Future<void> pumpMap(WidgetTester tester) async {
    controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          onReady: (vsync) => animator = MapCameraAnimator(controller, vsync),
        ),
      ),
    );
    await tester.pump();
  }

  const start = LatLng(46.05, 14.5);
  const target = LatLng(46.2, 14.9);

  testWidgets('glides to the target and stops there', (tester) async {
    await pumpMap(tester);
    animator.moveTo(target, 16, rotation: 0);
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-way: neither at the start nor at the target yet.
    expect(controller.camera.center, isNot(start));
    expect(controller.camera.center, isNot(target));
    expect(animator.isAnimating, isTrue);

    await tester.pumpAndSettle();
    expect(controller.camera.center.latitude, closeTo(target.latitude, 1e-9));
    expect(controller.camera.center.longitude, closeTo(target.longitude, 1e-9));
    expect(controller.camera.zoom, 16);
    expect(animator.isAnimating, isFalse);
  });

  testWidgets('jumps under reduced motion', (tester) async {
    await pumpMap(tester);
    animator.moveTo(target, 16, reduced: true);
    expect(controller.camera.center, target);
    expect(animator.isAnimating, isFalse);
  });

  testWidgets('stop leaves the camera mid-way', (tester) async {
    await pumpMap(tester);
    animator.moveTo(target, 16);
    await tester.pump(const Duration(milliseconds: 100));
    animator.stop();
    final stoppedAt = controller.camera.center;
    await tester.pumpAndSettle();
    expect(controller.camera.center, stoppedAt);
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.onReady});

  final MapController controller;
  final void Function(TickerProvider vsync) onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: const MapOptions(
        initialCenter: LatLng(46.05, 14.5),
        initialZoom: 12,
      ),
      children: const [],
    );
  }
}

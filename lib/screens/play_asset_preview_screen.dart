import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/log_entry.dart';
import '../models/map_layer.dart';
import '../models/navigation_target.dart';
import '../models/parcel.dart';
import '../theme/app_theme.dart';
import '../widgets/compass_painter.dart';
import '../widgets/log_card.dart';
import '../widgets/map_controls.dart';
import '../widgets/navigation_target_banner.dart';
import '../widgets/parcel_info_widgets.dart';
import '../widgets/parcel_wood_tracking_card.dart';

class PlayAssetPreviewApp extends StatelessWidget {
  final String kind;
  final String? outputPath;

  const PlayAssetPreviewApp({
    super.key,
    required this.kind,
    this.outputPath,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = kind == 'feature'
        ? const Size(1024, 500)
        : const Size(450, 950);
    final preview = MediaQuery(
      data: MediaQueryData(
        size: previewSize,
        devicePixelRatio: 1,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: SizedBox(
        width: previewSize.width,
        height: previewSize.height,
        child: PlayAssetPreviewScreen(kind: kind),
      ),
    );

    return MaterialApp(
      title: 'Gozdar Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.greenTheme,
      home: ColoredBox(
        color: const Color(0xFF10150F),
        child: Center(
          child: outputPath == null
              ? preview
              : _PreviewCapture(
                  kind: kind,
                  outputPath: outputPath!,
                  child: preview,
                ),
        ),
      ),
    );
  }
}

class _PreviewCapture extends StatefulWidget {
  final String kind;
  final String outputPath;
  final Widget child;

  const _PreviewCapture({
    required this.kind,
    required this.outputPath,
    required this.child,
  });

  @override
  State<_PreviewCapture> createState() => _PreviewCaptureState();
}

class _PreviewCaptureState extends State<_PreviewCapture> {
  final GlobalKey _captureKey = GlobalKey();
  var _didCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capture();
    });
  }

  Future<void> _capture() async {
    if (_didCapture || !mounted) {
      return;
    }
    _didCapture = true;

    if (widget.kind == 'feature') {
      await precacheImage(const AssetImage('icon.png'), context);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      exit(1);
    }

    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      exit(1);
    }

    final file = File(widget.outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _captureKey,
      child: widget.child,
    );
  }
}

class PlayAssetPreviewScreen extends StatelessWidget {
  final String kind;

  const PlayAssetPreviewScreen({
    super.key,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'feature':
        return const _FeatureGraphicPreview();
      case 'map':
        return const _MapPreview();
      case 'parcel':
        return const _ParcelPreview();
      case 'logs':
        return const _LogsPreview();
      case 'navigation':
        return const _NavigationPreview();
      default:
        return Scaffold(
          body: Center(
            child: Text(
              'Unknown preview: $kind',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        );
    }
  }
}

class _FeatureGraphicPreview extends StatelessWidget {
  const _FeatureGraphicPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF192216),
              Color(0xFF29412A),
              Color(0xFF415E2F),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ForestBackdropPainter(),
              ),
            ),
            Positioned(
              left: 56,
              top: 56,
              bottom: 56,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(72),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 32,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 420,
              right: 72,
              top: 62,
              bottom: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x44FFFFFF)),
                    ),
                    child: const Text(
                      'GOZDAR',
                      style: TextStyle(
                        color: Color(0xFFE8E4DF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Terenska aplikacija\nza delo v gozdu',
                    style: TextStyle(
                      color: Color(0xFFF5F0EA),
                      fontSize: 46,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Parcele, hlodi, navigacija in evidence na enem mestu.',
                    style: TextStyle(
                      color: Color(0xFFE3DDD5),
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _FeatureChip(
                        icon: Icons.map,
                        label: 'Interaktivna karta',
                      ),
                      _FeatureChip(
                        icon: Icons.inventory_2,
                        label: 'Sledenje hlodovini',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC1A2418),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x335D4037)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFFD4A574),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8E4DF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    final target = NavigationTarget(
      name: 'Skladišče hlodov',
      location: const LatLng(45.6496, 14.5265),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapBackdropPainter(),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 108,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xD91A2418),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x335D4037)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E5435),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.park,
                      color: Color(0xFFD4E8C8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KO 1723 / parcela 54',
                          style: TextStyle(
                            color: Color(0xFFE8E4DF),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ortofoto, kataster in označene točke na terenu',
                          style: TextStyle(
                            color: Color(0xFFCBC5BC),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          NavigationTargetBanner(
            target: target,
            onTap: () {},
            onClose: () {},
          ),
          Positioned(
            top: 92,
            left: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _MapLegendChip(
                  color: Color(0xFFE6A35E),
                  label: 'Aktivna navigacija',
                ),
                SizedBox(height: 10),
                _MapLegendChip(
                  color: Color(0xFF8FBF6B),
                  label: 'Parcele v evidenci',
                ),
                SizedBox(height: 10),
                _MapLegendChip(
                  color: Color(0xFFD4A574),
                  label: 'Shranjene točke',
                ),
              ],
            ),
          ),
          MapControls(
            mapController: MapController(),
            currentBaseLayer: MapLayer.esriWorldImagery,
            locationsCount: 3,
            onLayerSelectorPressed: () {},
            onMeasurePressed: () {},
            onGpsPressed: () {},
            onLocationsPressed: () {},
            onSearchPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: const _PreviewNavigationBar(selectedIndex: 0),
    );
  }
}

class _MapLegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _MapLegendChip({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1A2418),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8E4DF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelPreview extends StatelessWidget {
  const _ParcelPreview();

  @override
  Widget build(BuildContext context) {
    final parcel = Parcel(
      id: 54,
      name: 'Bukov Vrh',
      polygon: const [
        LatLng(45.6492, 14.5241),
        LatLng(45.6501, 14.5262),
        LatLng(45.6494, 14.5281),
        LatLng(45.6484, 14.5275),
        LatLng(45.6481, 14.5250),
      ],
      createdAt: DateTime(2026, 4, 12),
      cadastralMunicipality: 1723,
      parcelNumber: '54',
      owner: 'Janez Kranjc',
      notes: 'Dostop z juga. Označene so tri točke za odvoz hlodovine.',
      forestType: ForestType.mixed,
      woodAllowance: 48.0,
      woodCut: 31.4,
      treesCut: 27,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcela Bukov Vrh'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ParcelInfoCard(
            parcel: parcel,
            onEditForestType: () {},
          ),
          const SizedBox(height: 12),
          ParcelOwnerCard(
            owner: parcel.owner,
            onEdit: () {},
          ),
          const SizedBox(height: 12),
          ParcelNotesCard(
            notes: parcel.notes,
            onEdit: () {},
          ),
          const SizedBox(height: 12),
          ParcelWoodTrackingCard(
            parcel: parcel,
            onEditAllowance: () {},
            onResetCut: () {},
            onResetTrees: () {},
            onLogWoodCut: () {},
            onLogTreesCut: () {},
          ),
        ],
      ),
      bottomNavigationBar: const _PreviewNavigationBar(selectedIndex: 1),
    );
  }
}

class _LogsPreview extends StatelessWidget {
  const _LogsPreview();

  @override
  Widget build(BuildContext context) {
    final logs = [
      LogEntry(
        id: 101,
        diameter: 48,
        length: 5.4,
        volume: 0.977,
        latitude: 45.6490,
        longitude: 14.5260,
        species: 'Smreka',
      ),
      LogEntry(
        id: 102,
        diameter: 41,
        length: 4.8,
        volume: 0.634,
        latitude: 45.6494,
        longitude: 14.5268,
        species: 'Bukev',
      ),
      LogEntry(
        id: 103,
        diameter: 36,
        length: 4.2,
        volume: 0.428,
        species: 'Jelka',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hlodi'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x335D4037)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skupaj neevidentirani hlodi',
                    style: TextStyle(
                      color: Color(0xFFCBC5BC),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '2.039 m³',
                    style: TextStyle(
                      color: Color(0xFFD4A574),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricBadge(
                        label: 'PRM',
                        value: '1.33',
                      ),
                      SizedBox(width: 10),
                      _MetricBadge(
                        label: 'NM',
                        value: '0.82',
                      ),
                      SizedBox(width: 10),
                      _MetricBadge(
                        label: 'GPS',
                        value: '2 vnosa',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final log in logs)
            LogCard(
              logEntry: log,
              onTap: () {},
              onDismissed: () {},
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E5435),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_copy,
                    color: Color(0xFFD4E8C8),
                  ),
                ),
                title: const Text('Projekt Bukov Vrh'),
                subtitle: const Text('3 hlodi • 2.04 m³'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _PreviewNavigationBar(selectedIndex: 2),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2418),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBC5BC),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8E4DF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview();

  @override
  Widget build(BuildContext context) {
    final currentPosition = Position(
      longitude: 14.52573,
      latitude: 45.64898,
      timestamp: DateTime(2026, 4, 18, 10, 30),
      accuracy: 4,
      altitude: 612,
      altitudeAccuracy: 1,
      heading: 18,
      headingAccuracy: 8,
      speed: 0.4,
      speedAccuracy: 0.1,
      isMocked: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigacija'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3A2A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x335D4037)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.navigation,
                  color: Color(0xFFE6A35E),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skladišče hlodov',
                        style: TextStyle(
                          color: Color(0xFFE8E4DF),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '386 m do cilja • smer JV',
                        style: TextStyle(
                          color: Color(0xFFCBC5BC),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3A2A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x335D4037)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: CompassPainter(
                      heading: 18,
                      hasHeading: true,
                      currentPosition: currentPosition,
                      targetLocation: const LatLng(45.6509, 14.5299),
                      theme: Theme.of(context),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavigationStat(
                      label: 'Razdalja',
                      value: '386 m',
                    ),
                    _NavigationStat(
                      label: 'Levo/desno',
                      value: '120°',
                    ),
                    _NavigationStat(
                      label: 'Točnost',
                      value: '±8°',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.place),
              title: const Text('GPS položaj'),
              subtitle: const Text('45.64898, 14.52573'),
              trailing: const Icon(Icons.gps_fixed),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.map),
            label: const Text('Odpri karto'),
          ),
        ],
      ),
      bottomNavigationBar: const _PreviewNavigationBar(selectedIndex: 0),
    );
  }
}

class _NavigationStat extends StatelessWidget {
  final String label;
  final String value;

  const _NavigationStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4A574),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCBC5BC),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PreviewNavigationBar extends StatelessWidget {
  final int selectedIndex;

  const _PreviewNavigationBar({
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Karta',
        ),
        NavigationDestination(
          icon: Icon(Icons.park_outlined),
          selectedIcon: Icon(Icons.park),
          label: 'Gozd',
        ),
        NavigationDestination(
          icon: Icon(Icons.forest_outlined),
          selectedIcon: Icon(Icons.forest),
          label: 'Hlodi',
        ),
      ],
    );
  }
}

class _ForestBackdropPainter extends CustomPainter {
  const _ForestBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hazePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.45, -0.35),
        radius: 1.2,
        colors: [
          Color(0x446CC26E),
          Color(0x00192216),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hazePaint);

    final hillPaint = Paint()..color = const Color(0x553A5A30);
    final backHill = Path()
      ..moveTo(-80, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.55,
        size.width * 0.52,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.84,
        size.width + 40,
        size.height * 0.58,
      )
      ..lineTo(size.width + 40, size.height + 40)
      ..lineTo(-80, size.height + 40)
      ..close();
    canvas.drawPath(backHill, hillPaint);

    final frontHill = Path()
      ..moveTo(-60, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.75,
        size.width * 0.48,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height,
        size.width + 40,
        size.height * 0.8,
      )
      ..lineTo(size.width + 40, size.height + 40)
      ..lineTo(-60, size.height + 40)
      ..close();
    canvas.drawPath(
      frontHill,
      Paint()..color = const Color(0xAA1A2418),
    );

    for (var index = 0; index < 9; index++) {
      final x = 110.0 + index * 100.0;
      final scale = index.isEven ? 1.0 : 0.75;
      _drawTree(
        canvas,
        Offset(x, size.height * 0.7 + (index % 3) * 12),
        46 * scale,
      );
    }
  }

  void _drawTree(Canvas canvas, Offset base, double size) {
    final treePath = Path()
      ..moveTo(base.dx, base.dy - size * 2.4)
      ..lineTo(base.dx - size * 0.55, base.dy - size * 1.2)
      ..lineTo(base.dx - size * 0.22, base.dy - size * 1.2)
      ..lineTo(base.dx - size * 0.7, base.dy)
      ..lineTo(base.dx - size * 0.28, base.dy)
      ..lineTo(base.dx - size * 0.82, base.dy + size * 1.15)
      ..lineTo(base.dx + size * 0.82, base.dy + size * 1.15)
      ..lineTo(base.dx + size * 0.28, base.dy)
      ..lineTo(base.dx + size * 0.7, base.dy)
      ..lineTo(base.dx + size * 0.22, base.dy - size * 1.2)
      ..lineTo(base.dx + size * 0.55, base.dy - size * 1.2)
      ..close();

    canvas.drawPath(
      treePath,
      Paint()..color = const Color(0xAA0F2B11),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2B3A27),
          Color(0xFF48553A),
          Color(0xFF697248),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final parcelPaint = Paint()
      ..color = const Color(0x5537B24D)
      ..style = PaintingStyle.fill;
    final parcelStroke = Paint()
      ..color = const Color(0xFF8FBF6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final parcelA = Path()
      ..moveTo(42, 244)
      ..lineTo(172, 194)
      ..lineTo(232, 286)
      ..lineTo(148, 388)
      ..lineTo(52, 338)
      ..close();
    canvas.drawPath(parcelA, parcelPaint);
    canvas.drawPath(parcelA, parcelStroke);

    final parcelB = Path()
      ..moveTo(206, 164)
      ..lineTo(344, 144)
      ..lineTo(382, 258)
      ..lineTo(286, 330)
      ..lineTo(214, 258)
      ..close();
    canvas.drawPath(parcelB, parcelPaint);
    canvas.drawPath(parcelB, parcelStroke);

    final contourPaint = Paint()
      ..color = const Color(0x33F5F0EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var index = 0; index < 7; index++) {
      final y = 90.0 + index * 92.0;
      final path = Path()
        ..moveTo(-20, y)
        ..quadraticBezierTo(
          size.width * 0.25,
          y - 28,
          size.width * 0.5,
          y + 18,
        )
        ..quadraticBezierTo(
          size.width * 0.75,
          y + 44,
          size.width + 30,
          y + 10,
        );
      canvas.drawPath(path, contourPaint);
    }

    final dashedPaint = Paint()
      ..color = const Color(0x88F4D58D)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 12; index++) {
      final start = Offset(96 + index * 23, 462 + math.sin(index * 0.7) * 14);
      final end = Offset(start.dx + 12, start.dy + 4);
      canvas.drawLine(start, end, dashedPaint);
    }

    final markerPaint = Paint()..color = const Color(0xFFD4A574);
    for (final point in const [
      Offset(132, 278),
      Offset(286, 220),
      Offset(306, 510),
    ]) {
      canvas.drawCircle(point, 12, markerPaint);
      canvas.drawCircle(
        point.translate(0, 20),
        4,
        Paint()..color = const Color(0xAA000000),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Navigiraj" chooser: hand the destination to the phone's navigation app
/// (Google Maps, Apple Maps), use the in-app compass, or copy the coordinates.
///
/// Shown from the map long-press menu and the parcel detail screen.
class NavigateToSheet extends StatelessWidget {
  final LatLng destination;
  final String name;

  /// Start the in-app compass navigation to [destination].
  final VoidCallback onInAppNavigation;

  const NavigateToSheet({
    super.key,
    required this.destination,
    required this.name,
    required this.onInAppNavigation,
  });

  static Future<void> show(
    BuildContext context, {
    required LatLng destination,
    required String name,
    required VoidCallback onInAppNavigation,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => NavigateToSheet(
        destination: destination,
        name: name,
        onInAppNavigation: onInAppNavigation,
      ),
    );
  }

  /// "46.123456, 14.123456" — the format map apps and the clipboard expect.
  static String coordinates(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

  static String _q(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

  /// Candidate URLs for turn-by-turn navigation in Google Maps, most direct
  /// first. On Android `google.navigation:` starts navigation immediately; the
  /// https form works everywhere (opens the app when installed, else browser).
  @visibleForTesting
  static List<Uri> googleMapsUris(LatLng p, {TargetPlatform? platform}) {
    final q = _q(p);
    final os = platform ?? defaultTargetPlatform;
    return [
      if (os == TargetPlatform.android) Uri.parse('google.navigation:q=$q'),
      if (os == TargetPlatform.iOS)
        Uri.parse('comgooglemaps://?daddr=$q&directionsmode=driving'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving',
      ),
    ];
  }

  /// Apple Maps directions (iOS / macOS only).
  @visibleForTesting
  static Uri appleMapsUri(LatLng p) =>
      Uri.parse('https://maps.apple.com/?daddr=${_q(p)}&dirflg=d');

  static bool get _hasAppleMaps =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> _launchFirst(BuildContext context, List<Uri> uris) async {
    final messenger = ScaffoldMessenger.of(context);
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (e) {
        debugPrint('NavigateToSheet: $uri failed: $e');
      }
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Aplikacije za navigacijo ni bilo mogoče odpreti.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    coordinates(destination),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Google Zemljevidi'),
              subtitle: const Text('Navigacija po cesti'),
              onTap: () {
                Navigator.pop(context);
                _launchFirst(context, googleMapsUris(destination));
              },
            ),
            if (_hasAppleMaps)
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Apple Zemljevidi'),
                subtitle: const Text('Navigacija po cesti'),
                onTap: () {
                  Navigator.pop(context);
                  _launchFirst(context, [appleMapsUri(destination)]);
                },
              ),
            ListTile(
              leading: const Icon(Icons.explore),
              title: const Text('Kompas v aplikaciji'),
              subtitle: const Text(
                'Smer in razdalja do cilja, tudi brez spleta',
              ),
              onTap: () {
                Navigator.pop(context);
                onInAppNavigation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Kopiraj koordinate'),
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                Clipboard.setData(
                  ClipboardData(text: coordinates(destination)),
                );
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Koordinate kopirane'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

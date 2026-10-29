import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import 'sheet_parts.dart';

/// "Navigiraj" chooser: hand the destination to the phone's navigation app
/// (Google Maps, Apple Maps), use the in-app compass, or copy the coordinates.
///
/// Shown from the map long-press menu and the parcel detail screen.
class NavigateToSheet extends StatelessWidget {
  final LatLng destination;
  final String name;

  /// Start the in-app compass navigation to [destination].
  final VoidCallback onInAppNavigation;

  /// Reopen the panel this sheet came from; plain close when null.
  final VoidCallback? onBack;

  const NavigateToSheet({
    super.key,
    required this.destination,
    required this.name,
    required this.onInAppNavigation,
    this.onBack,
  });

  static Future<void> show(
    BuildContext context, {
    required LatLng destination,
    required String name,
    required VoidCallback onInAppNavigation,
    VoidCallback? onBack,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => NavigateToSheet(
        destination: destination,
        name: name,
        onInAppNavigation: onInAppNavigation,
        onBack: onBack,
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
    final failedText = context.l10n.mapwNavAppOpenFailed;
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (e) {
        debugPrint('NavigateToSheet: $uri failed: $e');
      }
    }
    messenger.showSnackBar(
      SnackBar(content: Text(failedText)),
    );
  }

  void _copy(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    Clipboard.setData(ClipboardData(text: coordinates(destination)));
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.mapwCoordinatesCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            SheetHeader(
              // Same icon and tint as the Navigiraj tile that opens this.
              icon: Icons.navigation,
              color: Colors.indigo.shade200,
              title: name,
              subtitle: coordinates(destination),
              onBack: onBack == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onBack!();
                    },
            ),
            const SizedBox(height: 12),
            SheetTileRow([
              SheetTile(
                icon: Icons.directions,
                label: context.l10n.mapwGoogleMaps,
                color: Colors.green.shade300,
                onTap: () {
                  Navigator.pop(context);
                  _launchFirst(context, googleMapsUris(destination));
                },
              ),
              if (_hasAppleMaps)
                SheetTile(
                  icon: Icons.map_outlined,
                  label: context.l10n.mapwAppleMaps,
                  color: Colors.lightBlue.shade300,
                  onTap: () {
                    Navigator.pop(context);
                    _launchFirst(context, [appleMapsUri(destination)]);
                  },
                ),
              SheetTile(
                icon: Icons.explore,
                label: context.l10n.mapwInAppCompass,
                color: cs.primary,
                onTap: () {
                  Navigator.pop(context);
                  onInAppNavigation();
                },
              ),
              SheetTile(
                icon: Icons.copy,
                label: context.l10n.mapwCopyCoordinates,
                color: cs.onSurfaceVariant,
                onTap: () => _copy(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

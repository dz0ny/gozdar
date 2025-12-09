import 'package:flutter/material.dart';
import '../models/map_location.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../widgets/worker_settings_dialog.dart';

/// Manages dialog operations for the map
class MapDialogManager {
  final BuildContext context;
  final Function(MapLocation) onDeleteLocation;
  final Function() onShowTileDownloadDialog;
  final VoidCallback? onResetOnboarding;

  const MapDialogManager({
    required this.context,
    required this.onDeleteLocation,
    required this.onShowTileDownloadDialog,
    this.onResetOnboarding,
  });

  /// Show delete location confirmation dialog
  Future<void> showDeleteLocationDialog(MapLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši lokacijo'),
        content: Text('Ali res želite izbrisati lokacijo "${location.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteLocation(location.id);
      onDeleteLocation(location);
      AnalyticsService().logLocationDeleted();
    }
  }

  /// Show worker settings dialog
  void showWorkerSettingsDialog() {
    AnalyticsService().logWorkerSettingsOpened();
    showDialog(
      context: context,
      builder: (context) =>
          WorkerSettingsDialog(onOpenDownload: onShowTileDownloadDialog),
    );
  }

  /// Show reset onboarding confirmation
  Future<void> showResetOnboardingDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi uvodni vodič'),
        content: const Text(
          'Ali res želite ponastaviti uvodni vodič? Ponovno zaženite aplikacijo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ponastavi'),
          ),
        ],
      ),
    );

    if (confirmed == true && onResetOnboarding != null) {
      onResetOnboarding!();
    }
  }
}

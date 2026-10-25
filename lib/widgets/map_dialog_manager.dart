import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/map_location.dart';
import '../services/database_service.dart';

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
        title: Text(context.l10n.mapwDeleteLocationTitle),
        content: Text(context.l10n.mapwDeleteLocationQuestion(location.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteLocation(location.id);
      onDeleteLocation(location);
    }
  }

  /// Show reset onboarding confirmation
  Future<void> showResetOnboardingDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mapwResetOnboardingTitle),
        content: Text(context.l10n.mapwResetOnboardingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.mapwReset),
          ),
        ],
      ),
    );

    if (confirmed == true && onResetOnboarding != null) {
      onResetOnboarding!();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/map_provider.dart';
import '../router/route_names.dart';
import '../services/onboarding_service.dart';
import '../services/secnja_share_service.dart';

/// Opens a sečnja share link: downloads the share, stores it and goes to the
/// map with a short message about the result.
class ReceiveShareScreen extends StatefulWidget {
  final String shareId;

  const ReceiveShareScreen({super.key, required this.shareId});

  @override
  State<ReceiveShareScreen> createState() => _ReceiveShareScreenState();
}

class _ReceiveShareScreenState extends State<ReceiveShareScreen> {
  @override
  void initState() {
    super.initState();
    // Inherited widgets are not ready in initState; start after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _receive());
  }

  Future<void> _receive() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final mapProvider = Provider.of<MapProvider?>(context, listen: false);
    String message;
    try {
      final result = await SecnjaShareService.instance.receive(widget.shareId);
      final payload = result.payload;
      switch (result.outcome) {
        case ReceiveOutcome.imported:
          message = l10n.secnjaReceived(payload!.parcelNumber, payload.points.length);
          await mapProvider?.loadReceivedShares();
          mapProvider?.focusOn(payload);
        case ReceiveOutcome.expired:
          message = l10n.secnjaLinkExpired;
          await mapProvider?.loadReceivedShares();
        case ReceiveOutcome.offline:
          message = l10n.secnjaNoConnection;
        case ReceiveOutcome.invalid:
          message = l10n.secnjaLinkInvalid;
      }
    } catch (e) {
      // Never leave the user on this screen: it has no way back.
      debugPrint('Receiving share ${widget.shareId} failed: $e');
      message = l10n.secnjaLinkInvalid;
    }
    if (!mounted) return;
    // A first start still shows the intro after the share is stored.
    context.go(OnboardingService.instance.isOnboardingCompleted
        ? AppRoutes.map
        : AppRoutes.onboarding);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.receivedLoading),
          ],
        ),
      ),
    );
  }
}

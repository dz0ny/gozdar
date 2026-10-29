import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/kataster_sharing_service.dart';

/// Switch that lets phones on the same Wi-Fi download this phone's offline
/// kataster regions from it, with how many such phones are around.
class KatasterShareTile extends StatefulWidget {
  const KatasterShareTile({super.key});

  @override
  State<KatasterShareTile> createState() => _KatasterShareTileState();
}

class _KatasterShareTileState extends State<KatasterShareTile> {
  StreamSubscription<Set<KatasterPeer>>? _peersSubscription;
  bool _sharing = KatasterSharingService.instance.isSharing;
  int _peerCount = KatasterSharingService.instance.peers.length;

  @override
  void initState() {
    super.initState();
    _peersSubscription = KatasterSharingService.instance.peersStream.listen(
      (peers) {
        if (mounted) setState(() => _peerCount = peers.length);
      },
    );
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(Icons.wifi_tethering,
          color: Theme.of(context).colorScheme.primary),
      title: Text(context.l10n.aboutShareKataster),
      subtitle: Text(
        _sharing
            ? context.l10n.aboutShareKatasterActive(_peerCount)
            : context.l10n.aboutShareKatasterDesc,
      ),
      value: _sharing,
      onChanged: (enabled) async {
        if (enabled) {
          await KatasterSharingService.instance.startSharing();
        } else {
          await KatasterSharingService.instance.stopSharing();
        }
        if (mounted) {
          setState(() => _sharing = KatasterSharingService.instance.isSharing);
        }
      },
    );
  }
}

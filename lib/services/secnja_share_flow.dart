import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/parcel.dart';
import '../models/secnja_share.dart';
import 'database_service.dart';
import 'ko_locator.dart';
import 'owner_lookup_service.dart';
import 'secnja_share_service.dart';
import 'species_service.dart';

enum SecnjaShareState { notShared, sharedUnchanged, sharedChanged }

/// Share state of [parcel], given the hash of its marks as they are now.
/// A link past its expiry counts as not shared, so the next share makes a new one.
SecnjaShareState secnjaShareState(Parcel parcel, String currentHash) {
  final expires = parcel.shareExpiresAt;
  if (!parcel.isShared || (expires != null && !expires.isAfter(DateTime.now()))) {
    return SecnjaShareState.notShared;
  }
  return parcel.shareHash == currentHash
      ? SecnjaShareState.sharedUnchanged
      : SecnjaShareState.sharedChanged;
}

/// Builds the share payload of [parcel] from the marks in the database.
Future<SecnjaSharePayload> buildSecnjaPayload(Parcel parcel) async {
  final marks = await DatabaseService().getSecnjaByParcel(parcel.id);
  final ko = parcel.cadastralMunicipality;
  final koName = ko == null
      ? null
      : OwnerLookupService.instance.koName(ko) ?? KoLocator.instance.bySifko(ko)?.name;
  return SecnjaSharePayload.fromParcel(
    parcel,
    marks,
    koName: koName,
    species: await SpeciesService().getSpecies(),
  );
}

/// Uploads the marks of [parcel] when they changed, then opens the system
/// share sheet with the link for the logger.
/// Returns false when the upload failed.
Future<bool> runSecnjaShare(BuildContext context, Parcel parcel) async {
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final service = SecnjaShareService.instance;
  final payload = await buildSecnjaPayload(parcel);
  try {
    final state = secnjaShareState(parcel, payload.contentHash);
    final Uri link;
    if (state == SecnjaShareState.sharedUnchanged) {
      link = service.linkFor(parcel.shareId!);
      payload.expiresAt = parcel.shareExpiresAt;
    } else {
      final result = await service.share(parcel, payload);
      link = result.link;
      payload.expiresAt = result.expiresAt;
    }
    final title = shareTitle(payload, L10n.current);
    await SharePlus.instance.share(
      ShareParams(
        uri: link,
        title: title,
        subject: title,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    return true;
  } on ShareException {
    messenger.showSnackBar(
      SnackBar(content: Text(L10n.current.secnjaShareFailed)),
    );
    return false;
  }
}

/// Asks to confirm, then deletes the link of [parcel].
/// Returns true when the link is gone.
Future<bool> runSecnjaRevoke(BuildContext context, Parcel parcel) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(context.l10n.secnjaRevokeConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.secnjaRevoke),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await SecnjaShareService.instance.revoke(parcel);
    return true;
  } on ShareException {
    messenger.showSnackBar(
      SnackBar(content: Text(L10n.current.secnjaShareFailed)),
    );
    return false;
  }
}

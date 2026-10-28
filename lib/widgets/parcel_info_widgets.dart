import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/parcel.dart';
import '../services/ko_locator.dart';
import '../services/owner_lookup_service.dart';
import '../screens/forest_tab.dart';
import '../l10n/l10n.dart';
import 'owner_list.dart';

/// One fact about the parcel: a tinted icon, a small label and the value in
/// large type, so it reads at arm's length outdoors.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parcel info card showing basic parcel information
class ParcelInfoCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onEditForestType;

  const ParcelInfoCard({
    super.key,
    required this.parcel,
    required this.onEditForestType,
  });

  /// KO name with its number, e.g. "STARI TRG (1650)", from the owners DB or
  /// the bundled KO index (which covers Croatia too); the bare number when
  /// neither knows it.
  String _koValue(int? sifko) {
    final name = OwnerLookupService.instance.koName(sifko) ??
        KoLocator.instance.bySifko(sifko)?.name;
    return name != null ? '$name ($sifko)' : sifko.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. M. yyyy', context.l10n.localeName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onEditForestType,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getForestTypeIcon(
                        parcel.forestType,
                      ).$2.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      getForestTypeIcon(parcel.forestType).$1,
                      size: 32,
                      color: getForestTypeIcon(parcel.forestType).$2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.areaFormatted,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      Text(
                        context.l10n.parcelPointsCount(parcel.polygon.length),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (parcel.isCadastral) ...[
              // The KO index loads lazily; rebuild with the name once it has.
              FutureBuilder<void>(
                future: KoLocator.instance.ensureLoaded(),
                builder: (context, _) => _InfoTile(
                  icon: Icons.location_city,
                  label: context.l10n.parcelInfoKo,
                  value: _koValue(parcel.cadastralMunicipality),
                ),
              ),
              _InfoTile(
                icon: Icons.tag,
                label: context.l10n.parcelInfoParcel,
                value: parcel.parcelNumber!,
              ),
            ],
            _InfoTile(
              icon: Icons.calendar_today,
              label: context.l10n.parcelInfoAdded,
              value: dateFormat.format(parcel.createdAt),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner information card: one row per owner (with share and address when
/// known), the first few inline and the rest behind "Pokaži vse".
class ParcelOwnerCard extends StatelessWidget {
  /// Owners typed in or saved on import, joined with [OwnerInfo.separator].
  final String? owner;
  final VoidCallback onEdit;

  /// Owners looked up from the cadastre. Their names show when [owner] is
  /// empty; their shares and addresses fill in the rows either way.
  final OwnerInfo? lookedUp;

  static const _inline = 3;

  const ParcelOwnerCard({
    super.key,
    required this.owner,
    required this.onEdit,
    this.lookedUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manual = OwnerInfo.split(owner);
    final lookedUpOwners = lookedUp?.owners ?? const <String>[];
    final names = manual.isNotEmpty ? manual : lookedUpOwners;
    final fromCadastre = manual.isEmpty && lookedUpOwners.isNotEmpty;
    final hasHolderAddresses =
        lookedUp?.holders.any((h) => h.address != null) ?? false;
    // A parcel-level address (Slovenian owners DB) when there are no
    // per-owner ones.
    final address = hasHolderAddresses ? null : lookedUp?.address;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(
              names.length > 1
                  ? context.l10n.ownersTitle(names.length)
                  : context.l10n.parcelOwnerTitle,
            ),
            subtitle: names.isEmpty ? Text(context.l10n.parcelNotSet) : null,
            trailing: const Icon(Icons.edit),
            onTap: onEdit,
          ),
          if (names.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in names.take(_inline))
                    OwnerTile(
                      holder: lookedUp?.holder(name) ?? OwnerHolder(name),
                      dense: true,
                    ),
                  if (names.length > _inline)
                    TextButton.icon(
                      onPressed: () => OwnersSheet.show(
                        context,
                        owners: names,
                        info: lookedUp,
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: Text(context.l10n.ownersShowAll(names.length)),
                    ),
                  if (address != null && address.isNotEmpty)
                    Text(address, style: muted),
                  if (fromCadastre || address != null)
                    Text(
                      context.l10n.parcelFromCadastre,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Notes card
class ParcelNotesCard extends StatelessWidget {
  final String? notes;
  final VoidCallback onEdit;

  const ParcelNotesCard({super.key, required this.notes, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.note),
        title: Text(context.l10n.parcelNotesTitle),
        subtitle: Text(notes ?? context.l10n.parcelNoNotes),
        trailing: const Icon(Icons.edit),
        onTap: onEdit,
      ),
    );
  }
}

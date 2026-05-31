import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/parcel.dart';
import '../services/owner_lookup_service.dart';
import '../screens/forest_tab.dart';

/// Info row widget for displaying label-value pairs
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
          ),
        ),
      ],
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

  /// KO code, enriched with the cadastral municipality name when the owners
  /// DB is imported, e.g. "STARI TRG (1650)" instead of "1650".
  String _koValue(int? sifko) {
    final name = OwnerLookupService.instance.koName(sifko);
    return name != null ? '$name ($sifko)' : sifko.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. M. yyyy');

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
                        '${parcel.polygon.length} tock',
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
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Dodano',
              value: dateFormat.format(parcel.createdAt),
            ),
            if (parcel.isCadastral) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_city,
                label: 'KO',
                value: _koValue(parcel.cadastralMunicipality),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.tag,
                label: 'Parcela',
                value: parcel.parcelNumber!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Owner information card
class ParcelOwnerCard extends StatelessWidget {
  final String? owner;
  final VoidCallback onEdit;

  /// Owner name(s) looked up from the imported cadastral owners database.
  /// Shown (read-only, labelled "iz katastra") only when the manual [owner]
  /// field is empty.
  final String? lookedUpOwner;
  final String? lookedUpAddress;

  const ParcelOwnerCard({
    super.key,
    required this.owner,
    required this.onEdit,
    this.lookedUpOwner,
    this.lookedUpAddress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasManual = owner != null && owner!.isNotEmpty;
    final hasLookupOwner = lookedUpOwner != null && lookedUpOwner!.isNotEmpty;
    final hasLookupAddress =
        lookedUpAddress != null && lookedUpAddress!.isNotEmpty;

    // Owner name: manual takes priority, otherwise the looked-up name.
    final name = hasManual ? owner : (hasLookupOwner ? lookedUpOwner : null);
    // Show the looked-up address (NASLOV, OBČINA) whenever available; show the
    // GURS caption whenever any data comes from the cadastre.
    final showsCadastre = hasLookupAddress || (!hasManual && hasLookupOwner);

    Widget subtitle;
    if (name == null) {
      subtitle = const Text('Ni dolocen');
    } else {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name),
          if (hasLookupAddress)
            Text(
              lookedUpAddress!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (showsCadastre)
            Text(
              'iz katastra (GURS)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: const Text('Lastnik'),
        subtitle: subtitle,
        isThreeLine: name != null && (hasLookupAddress || showsCadastre),
        trailing: const Icon(Icons.edit),
        onTap: onEdit,
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
        title: const Text('Opombe'),
        subtitle: Text(notes ?? 'Ni opomb'),
        trailing: const Icon(Icons.edit),
        onTap: onEdit,
      ),
    );
  }
}

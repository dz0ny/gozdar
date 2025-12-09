import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/parcel.dart';
import '../widgets/parcel_silhouette.dart';
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
                  child: parcel.polygon.isNotEmpty
                      ? ParcelSilhouette(
                          polygon: parcel.polygon,
                          size: 72,
                          fillColor: getForestTypeIcon(
                            parcel.forestType,
                          ).$2.withValues(alpha: 0.3),
                          strokeColor: getForestTypeIcon(parcel.forestType).$2,
                          strokeWidth: 2,
                        )
                      : Container(
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
                value: parcel.cadastralMunicipality.toString(),
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

  const ParcelOwnerCard({super.key, required this.owner, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: const Text('Lastnik'),
        subtitle: Text(owner ?? 'Ni dolocen'),
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

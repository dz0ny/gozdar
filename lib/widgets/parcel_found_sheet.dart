import 'package:flutter/material.dart';
import '../models/parcel.dart';
import '../services/cadastral_service.dart';
import 'parcel_silhouette.dart';

/// Bottom sheet displayed when a parcel is found from search
/// Shows parcel details and allows viewing or importing the parcel
class ParcelFoundSheet extends StatelessWidget {
  final WfsParcel wfsParcel;
  final Parcel? existingParcel;
  final VoidCallback onHide;
  final VoidCallback onAction;

  const ParcelFoundSheet({
    super.key,
    required this.wfsParcel,
    required this.existingParcel,
    required this.onHide,
    required this.onAction,
  });

  /// Show the parcel found sheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required WfsParcel wfsParcel,
    required Parcel? existingParcel,
    required VoidCallback onHide,
    required VoidCallback onAction,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ParcelFoundSheet(
        wfsParcel: wfsParcel,
        existingParcel: existingParcel,
        onHide: onHide,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parcela najdena',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      existingParcel != null
                          ? 'Vaša parcela'
                          : 'Pregled meje parcele',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Card with parcel preview
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: 0.3,
                ),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ParcelSilhouette(
                  polygon: wfsParcel.polygon,
                  size: 56,
                  fillColor: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.3,
                  ),
                  strokeColor: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
              title: Text(
                'Parcela ${wfsParcel.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.map,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'KO ${wfsParcel.nationalCadastralReference}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.square_foot,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wfsParcel.formattedArea,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onHide();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Skrij'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAction();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    existingParcel != null
                        ? Icons.visibility
                        : Icons.download,
                  ),
                  label: Text(
                    existingParcel != null
                        ? 'Odpri parcelo'
                        : 'Uvozi parcelo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

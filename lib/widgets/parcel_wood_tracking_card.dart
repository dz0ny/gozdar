import 'package:flutter/material.dart';
import '../models/parcel.dart';

/// Wood tracking card showing allowance, cut amount, progress, and action buttons
class ParcelWoodTrackingCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onEditAllowance;
  final VoidCallback onResetCut;
  final VoidCallback onResetTrees;
  final VoidCallback onLogWoodCut;
  final VoidCallback onLogTreesCut;

  const ParcelWoodTrackingCard({
    super.key,
    required this.parcel,
    required this.onEditAllowance,
    required this.onResetCut,
    required this.onResetTrees,
    required this.onLogWoodCut,
    required this.onLogTreesCut,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forest, color: Colors.brown),
                const SizedBox(width: 8),
                Text(
                  'Posek lesa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Allowance
            InkWell(
              onTap: onEditAllowance,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dovoljen posek',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          Text(
                            parcel.woodAllowance > 0
                                ? '${parcel.woodAllowance.toStringAsFixed(2)} m³'
                                : 'Ni dolocen',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const Divider(),

            // Cut amount with progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Posekano',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${parcel.woodCut.toStringAsFixed(2)} m³',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (parcel.woodCut > 0)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ponastavi',
                    onPressed: onResetCut,
                  ),
              ],
            ),

            // Progress bar if allowance is set
            if (parcel.woodAllowance > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: parcel.woodUsedPercent / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    parcel.woodUsedPercent >= 100
                        ? Colors.red
                        : parcel.woodUsedPercent >= 80
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${parcel.woodUsedPercent.toStringAsFixed(0)}% izkorisceno',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Se na voljo: ${parcel.woodRemaining.toStringAsFixed(2)} m³',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(),

            // Trees cut
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Posekanih dreves',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${parcel.treesCut}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (parcel.treesCut > 0)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ponastavi',
                    onPressed: onResetTrees,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onLogWoodCut,
                    icon: const Icon(Icons.add),
                    label: const Text('Posek m³'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLogTreesCut,
                    icon: const Icon(Icons.nature),
                    label: const Text('Drevo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

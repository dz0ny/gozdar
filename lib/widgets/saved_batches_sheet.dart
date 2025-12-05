import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/log_batch.dart';
import '../providers/logs_provider.dart';
import '../screens/batch_detail_screen.dart';

/// Bottom sheet displaying saved log batches/projects
class SavedBatchesSheet extends StatefulWidget {
  const SavedBatchesSheet({super.key});

  @override
  State<SavedBatchesSheet> createState() => _SavedBatchesSheetState();
}

class _SavedBatchesSheetState extends State<SavedBatchesSheet> {
  @override
  void initState() {
    super.initState();
    // Load batches when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogsProvider>().loadBatches();
    });
  }

  Future<void> _deleteBatch(LogBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši'),
        content: const Text('Ali ste prepričani?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true && batch.id != null && mounted) {
      await context.read<LogsProvider>().deleteBatch(batch.id!);
    }
  }

  Future<void> _openBatchDetail(LogBatch batch) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BatchDetailScreen(batch: batch),
      ),
    );
    // Always reload batches after returning (logs may have been added/removed)
    if (mounted) {
      context.read<LogsProvider>().loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. M. yyyy HH:mm');

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Shranjene meritve',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<LogsProvider>(
                builder: (context, provider, child) {
                  if (provider.isBatchesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final batches = provider.batches;

                  if (batches.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(
                            'Ni shranjenih meritev',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  final factors = provider.conversionFactors;
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: batches.length,
                    itemBuilder: (context, index) {
                      final batch = batches[index];
                      final prmVolume = batch.totalVolume * factors.prm;
                      final nmVolume = batch.totalVolume * factors.nm;
                      return Dismissible(
                        key: Key('batch_${batch.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteBatch(batch);
                          return false;
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _openBatchDetail(batch),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Volume summary row
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${batch.totalVolume.toStringAsFixed(2)} m³',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[400],
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${prmVolume.toStringAsFixed(2)} PRM  •  ${nmVolume.toStringAsFixed(2)} NM',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.grey[500],
                                                ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${batch.logCount} hlodov',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey[500],
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // Metadata row
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          batch.owner ?? 'Brez lastnika',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontStyle: batch.owner == null ? FontStyle.italic : FontStyle.normal,
                                            color: batch.owner == null ? Colors.grey : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (batch.hasLocation) ...[
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                      ],
                                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(batch.createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  if (batch.notes != null && batch.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      batch.notes!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

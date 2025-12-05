import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_batch.dart';
import '../services/database_service.dart';
import '../screens/batch_detail_screen.dart';

/// Bottom sheet displaying saved log batches/projects
class SavedBatchesSheet extends StatefulWidget {
  final DatabaseService databaseService;

  const SavedBatchesSheet({
    super.key,
    required this.databaseService,
  });

  @override
  State<SavedBatchesSheet> createState() => _SavedBatchesSheetState();
}

class _SavedBatchesSheetState extends State<SavedBatchesSheet> {
  List<LogBatch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await widget.databaseService.getAllLogBatches();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    }
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

    if (confirmed == true && batch.id != null) {
      await widget.databaseService.deleteLogBatch(batch.id!);
      await _loadBatches();
    }
  }

  Future<void> _openBatchDetail(LogBatch batch) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BatchDetailScreen(batch: batch),
      ),
    );
    if (deleted == true) {
      await _loadBatches();
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
                    'Shranjeni hlodi',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _batches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text(
                                'Ni shranjenih hlodov',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _batches.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final batch = _batches[index];
                            return Dismissible(
                              key: Key('batch_${batch.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                await _deleteBatch(batch);
                                return false;
                              },
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        batch.totalVolume.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        'm³',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  batch.owner ?? 'Brez lastnika',
                                  style: TextStyle(
                                    fontStyle: batch.owner == null ? FontStyle.italic : FontStyle.normal,
                                    color: batch.owner == null ? Colors.grey : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${batch.logCount} hlodov • ${dateFormat.format(batch.createdAt)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    if (batch.notes != null)
                                      Text(
                                        batch.notes!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: batch.hasLocation
                                    ? Icon(Icons.location_on, size: 16, color: Colors.grey[600])
                                    : null,
                                isThreeLine: batch.notes != null,
                                onTap: () => _openBatchDetail(batch),
                              ),
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

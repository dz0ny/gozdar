import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/log_batch.dart';

/// Bottom sheet for saving logs as a batch/project
class SaveBatchSheet extends StatefulWidget {
  final double totalVolume;
  final int logCount;
  final Future<void> Function(LogBatch batch) onSave;

  const SaveBatchSheet({
    super.key,
    required this.totalVolume,
    required this.logCount,
    required this.onSave,
  });

  @override
  State<SaveBatchSheet> createState() => _SaveBatchSheetState();
}

class _SaveBatchSheetState extends State<SaveBatchSheet> {
  final _ownerController = TextEditingController();
  final _notesController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final batch = LogBatch(
        owner: _ownerController.text.isEmpty ? null : _ownerController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        latitude: _latitude,
        longitude: _longitude,
        totalVolume: widget.totalVolume,
        logCount: widget.logCount,
      );

      await widget.onSave(batch);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: [
                const Text(
                  'Nov projekt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${widget.totalVolume.toStringAsFixed(2)} m³',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Volumen',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${widget.logCount}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Hlodov',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Owner field
            TextField(
              controller: _ownerController,
              decoration: const InputDecoration(
                labelText: 'Lastnik',
                hintText: 'Ime lastnika',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Opombe',
                hintText: 'Dodatne opombe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                if (_latitude != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _latitude = null;
                            _longitude = null;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _isLoadingLocation ? null : _getLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('Dodaj lokacijo'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ustvari'),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

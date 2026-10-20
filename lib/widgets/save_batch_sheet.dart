import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/log_batch.dart';
import '../services/location_settings.dart';
import '../utils/sl_plural.dart';

/// "Shrani hlode": name the current working list and file it away, with an
/// optional GPS fix for where the pile sits. Notes can be added later from
/// the saved entry.
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

  /// Default name offered in the field: "Hlodi 18. 10. 2026".
  static String defaultName(DateTime now) =>
      'Hlodi ${DateFormat('d. M. yyyy').format(now)}';

  @override
  State<SaveBatchSheet> createState() => _SaveBatchSheetState();
}

class _SaveBatchSheetState extends State<SaveBatchSheet> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: SaveBatchSheet.defaultName(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dovoljenje za lokacijo zavrnjeno')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: GozdarLocationSettings.currentPosition,
      );
      if (!mounted) return;
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
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() => _isSaving = true);
    try {
      await widget.onSave(LogBatch(
        name: name.isEmpty ? null : name,
        latitude: _latitude,
        longitude: _longitude,
        totalVolume: widget.totalVolume,
        logCount: widget.logCount,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Napaka pri shranjevanju')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shrani hlode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.totalVolume.toStringAsFixed(2)} m³ • '
            '${slCount(widget.logCount, 'hlod', 'hloda', 'hlodi', 'hlodov')}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Ime',
              hintText: 'npr. Smreka za Novaka',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isSaving ? null : _save(),
          ),
          const SizedBox(height: 12),
          if (_latitude != null)
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _latitude = null;
                _longitude = null;
              }),
              icon: const Icon(Icons.location_on),
              label: Text(
                '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}  ✕',
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _isLoadingLocation ? null : _getLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Dodaj lokacijo'),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Shrani'),
          ),
        ],
      ),
    );
  }
}

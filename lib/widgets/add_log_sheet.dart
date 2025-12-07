import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/log_entry.dart';

/// Bottom sheet for adding a new log entry
class AddLogSheet extends StatefulWidget {
  final Future<void> Function(LogEntry entry) onAdd;
  final int? batchId;

  const AddLogSheet({
    super.key,
    required this.onAdd,
    this.batchId,
  });

  @override
  State<AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<AddLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _diameterFocus = FocusNode();

  double? _calculatedVolume;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _diameterFocus.dispose();
    super.dispose();
  }

  void _updateVolume() {
    final diameter = double.tryParse(_diameterController.text);
    final length = double.tryParse(_lengthController.text);

    setState(() {
      if (diameter != null && length != null && diameter > 0 && length > 0) {
        _calculatedVolume = LogEntry.calculateVolume(diameter, length);
      } else {
        _calculatedVolume = null;
      }
    });
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

  LogEntry? _createEntry() {
    if (!_formKey.currentState!.validate() || _calculatedVolume == null) {
      return null;
    }

    return LogEntry(
      diameter: double.parse(_diameterController.text),
      length: double.parse(_lengthController.text),
      volume: _calculatedVolume!,
      latitude: _latitude,
      longitude: _longitude,
      batchId: widget.batchId,
    );
  }

  Future<void> _saveAndContinue() async {
    final entry = _createEntry();
    if (entry == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onAdd(entry);
      setState(() {
        _addedCount++;
        _diameterController.clear();
        _lengthController.clear();
        _calculatedVolume = null;
      });
      _diameterFocus.requestFocus();
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _addedCount > 0 ? 'Dodaj (+$_addedCount)' : 'Dodaj',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diameterController,
                      focusNode: _diameterFocus,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Premer (cm)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) => v == null || v.isEmpty ? 'Vnesi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Dolžina (m)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) => v == null || v.isEmpty ? 'Vnesi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_calculatedVolume != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Volumen: ${_calculatedVolume!.toStringAsFixed(4)} m³',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
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
                      label: const Text('Lokacija'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _calculatedVolume != null && !_isSaving ? _saveAndContinue : null,
                    child: const Text('Dodaj'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

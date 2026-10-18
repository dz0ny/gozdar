import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/log_entry.dart';
import '../services/location_settings.dart';
import '../services/species_service.dart';
import '../utils/decimal_input.dart';

/// Always-visible quick-add bar at the bottom of the Hlodi tab: diameter,
/// length, species and an optional GPS fix, then "Dodaj". Replaces the modal
/// add sheet so logging a pile of timber is a steady type → Dodaj → type loop
/// without a popup in between. Stays put after each add (fields cleared, focus
/// back on the diameter) and counts what was added in this sitting.
class InlineAddLog extends StatefulWidget {
  final Future<void> Function(LogEntry entry) onAdd;
  final int? batchId;

  const InlineAddLog({super.key, required this.onAdd, this.batchId});

  @override
  State<InlineAddLog> createState() => _InlineAddLogState();
}

class _InlineAddLogState extends State<InlineAddLog> {
  final _formKey = GlobalKey<FormState>();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _diameterFocus = FocusNode();
  final _lengthFocus = FocusNode();

  double? _calculatedVolume;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  int _addedCount = 0;

  final _speciesService = SpeciesService();
  List<String> _availableSpecies = [];
  String? _selectedSpecies;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
  }

  Future<void> _loadSpecies() async {
    final species = await _speciesService.getSpecies();
    if (!mounted) return;
    setState(() => _availableSpecies = species);
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _diameterFocus.dispose();
    _lengthFocus.dispose();
    super.dispose();
  }

  void _updateVolume() {
    final diameter = parseDecimal(_diameterController.text);
    final length = parseDecimal(_lengthController.text);
    setState(() {
      _calculatedVolume =
          (diameter != null && length != null && diameter > 0 && length > 0)
              ? LogEntry.calculateVolume(diameter, length)
              : null;
    });
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

  LogEntry? _createEntry() {
    if (!_formKey.currentState!.validate() || _calculatedVolume == null) {
      return null;
    }
    return LogEntry(
      diameter: parseDecimal(_diameterController.text),
      length: parseDecimal(_lengthController.text),
      volume: _calculatedVolume!,
      latitude: _latitude,
      longitude: _longitude,
      species: _selectedSpecies,
      batchId: widget.batchId,
    );
  }

  Future<void> _saveAndContinue() async {
    final entry = _createEntry();
    if (entry == null) return;
    setState(() => _isSaving = true);
    try {
      await widget.onAdd(entry);
      if (!mounted) return;
      setState(() {
        _addedCount++;
        _diameterController.clear();
        _lengthController.clear();
        _calculatedVolume = null;
      });
      _diameterFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri shranjevanju: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canAdd = _calculatedVolume != null && !_isSaving;
    return Material(
      color: cs.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _diameterController,
                        focusNode: _diameterFocus,
                        decoration: _decoration('Premer (cm)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _lengthFocus.requestFocus(),
                        inputFormatters: [DecimalTextInputFormatter()],
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Vnesi' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _lengthController,
                        focusNode: _lengthFocus,
                        decoration: _decoration('Dolžina (m)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (canAdd) _saveAndContinue();
                        },
                        inputFormatters: [DecimalTextInputFormatter()],
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Vnesi' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedSpecies,
                        isExpanded: true,
                        decoration: _decoration('Vrsta'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('—'),
                          ),
                          ..._availableSpecies.map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedSpecies = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _calculatedVolume != null
                          ? Row(
                              children: [
                                const Icon(Icons.calculate,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${_calculatedVolume!.toStringAsFixed(4)} m³',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Vnesi premer in dolžino',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    if (_latitude != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _latitude = null;
                          _longitude = null;
                        }),
                        icon: const Icon(Icons.location_on, size: 16),
                        label: Text(
                          '${_latitude!.toStringAsFixed(3)}, ${_longitude!.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 12),
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
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: canAdd ? _saveAndContinue : null,
                      icon: const Icon(Icons.add),
                      label: Text(
                          _addedCount > 0 ? 'Dodaj (+$_addedCount)' : 'Dodaj'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

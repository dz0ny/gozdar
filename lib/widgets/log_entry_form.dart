import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/log_entry.dart';

class LogEntryForm extends StatefulWidget {
  final LogEntry? logEntry;

  const LogEntryForm({
    super.key,
    this.logEntry,
  });

  @override
  State<LogEntryForm> createState() => _LogEntryFormState();
}

class _LogEntryFormState extends State<LogEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _volumeController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isCalculateMode = true;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  double? _calculatedVolume;

  @override
  void initState() {
    super.initState();
    if (widget.logEntry != null) {
      _initializeFromEntry(widget.logEntry!);
    }
    _diameterController.addListener(_updateCalculatedVolume);
    _lengthController.addListener(_updateCalculatedVolume);
  }

  void _initializeFromEntry(LogEntry entry) {
    if (entry.diameter != null && entry.length != null) {
      _isCalculateMode = true;
      _diameterController.text = entry.diameter!.toStringAsFixed(1);
      _lengthController.text = entry.length!.toStringAsFixed(2);
    } else {
      _isCalculateMode = false;
      _volumeController.text = entry.volume.toStringAsFixed(3);
    }
    _notesController.text = entry.notes ?? '';
    _latitude = entry.latitude;
    _longitude = entry.longitude;
    _calculatedVolume = entry.volume;
  }

  void _updateCalculatedVolume() {
    final diameter = double.tryParse(_diameterController.text);
    final length = double.tryParse(_lengthController.text);

    if (diameter != null && length != null && diameter > 0 && length > 0) {
      setState(() {
        _calculatedVolume = LogEntry.calculateVolume(diameter, length);
      });
    } else {
      setState(() {
        _calculatedVolume = null;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokacijske storitve so onemogočene')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dovoljenja za lokacijo zavrnjena')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dovoljenja za lokacijo trajno zavrnjena'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokacija dodana')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri pridobivanju lokacije: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
  }

  void _saveEntry() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    double volume;
    double? diameter;
    double? length;

    if (_isCalculateMode) {
      if (_calculatedVolume == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prosim vnesite veljavne dimenzije')),
        );
        return;
      }
      diameter = double.parse(_diameterController.text);
      length = double.parse(_lengthController.text);
      volume = _calculatedVolume!;
    } else {
      volume = double.parse(_volumeController.text);
    }

    final entry = LogEntry(
      id: widget.logEntry?.id,
      diameter: diameter,
      length: length,
      volume: volume,
      latitude: _latitude,
      longitude: _longitude,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: widget.logEntry?.createdAt,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.logEntry == null ? 'Dodaj hlod' : 'Uredi hlod'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveEntry,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Način vnosa volumna',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Switch(
                          value: _isCalculateMode,
                          onChanged: (value) {
                            setState(() {
                              _isCalculateMode = value;
                              _calculatedVolume = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCalculateMode
                          ? 'Izračunaj iz dimenzij'
                          : 'Vnesi volumen neposredno',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isCalculateMode) ...[
              TextFormField(
                controller: _diameterController,
                decoration: const InputDecoration(
                  labelText: 'Premer (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                  helperText: 'Vnesite premer hloda v centimetrih',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Prosim vnesite premer';
                  }
                  final diameter = double.tryParse(value);
                  if (diameter == null || diameter <= 0) {
                    return 'Prosim vnesite veljaven premer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lengthController,
                decoration: const InputDecoration(
                  labelText: 'Dolžina (m)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                  helperText: 'Vnesite dolžino hloda v metrih',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Prosim vnesite dolžino';
                  }
                  final length = double.tryParse(value);
                  if (length == null || length <= 0) {
                    return 'Prosim vnesite veljavno dolžino';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_calculatedVolume != null)
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate, color: Colors.green),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izračunan volumen',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${_calculatedVolume!.toStringAsFixed(4)} m³',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              TextFormField(
                controller: _volumeController,
                decoration: const InputDecoration(
                  labelText: 'Volumen (m³)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                  helperText: 'Vnesite volumen v kubičnih metrih',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Prosim vnesite volumen';
                  }
                  final volume = double.tryParse(value);
                  if (volume == null || volume <= 0) {
                    return 'Prosim vnesite veljaven volumen';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Lokacija',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_latitude != null && _longitude != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(
                    'Lat: ${_latitude!.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    'Lon: ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _removeLocation,
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isLoadingLocation
                    ? 'Pridobivanje lokacije...'
                    : 'Dodaj trenutno lokacijo'),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Opombe (neobvezno)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                helperText: 'Dodajte morebitne opombe',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.save),
              label: const Text('Shrani hlod'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../services/database_service.dart';
import '../services/kml_service.dart';
import '../providers/logs_provider.dart';
import '../widgets/parcel_silhouette.dart';
import '../main.dart';
import 'parcel_editor.dart';
import 'forest_tab.dart' show getForestTypeIcon;

class ParcelDetailScreen extends StatefulWidget {
  final Parcel parcel;

  const ParcelDetailScreen({super.key, required this.parcel});

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Parcel _parcel;
  bool _isLoading = false;
  List<MapLocation> _locationsInParcel = []; // Regular POIs
  List<MapLocation> _secnjaInParcel = []; // Trees marked for cutting
  List<LogEntry> _logsInParcel = [];
  double _logsVolume = 0.0;
  LogsProvider? _logsProvider;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadLocationsInParcel();
    _loadLogsInParcel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to logs provider changes
    _logsProvider?.removeListener(_onLogsChanged);
    _logsProvider = context.read<LogsProvider>();
    _logsProvider?.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    _logsProvider?.removeListener(_onLogsChanged);
    super.dispose();
  }

  void _onLogsChanged() {
    // Reload logs when provider notifies of changes
    _loadLogsInParcel();
  }

  Future<void> _loadLocationsInParcel() async {
    try {
      final allLocations = await _databaseService.getAllLocations();
      final inParcel = allLocations
          .where(
            (loc) => _parcel.containsPoint(LatLng(loc.latitude, loc.longitude)),
          )
          .toList();
      setState(() {
        // Separate regular locations from sečnja markers
        _locationsInParcel = inParcel.where((loc) => !loc.isSecnja).toList();
        _secnjaInParcel = inParcel.where((loc) => loc.isSecnja).toList();
      });
    } catch (e) {
      debugPrint('Error loading locations in parcel: $e');
    }
  }

  Future<void> _loadLogsInParcel() async {
    if (_parcel.id == null) return;
    try {
      final logs = await _databaseService.getLogsByParcel(_parcel.id!);
      final volume = await _databaseService.getParcelTotalVolume(_parcel.id!);
      setState(() {
        _logsInParcel = logs;
        _logsVolume = volume;
      });
    } catch (e) {
      debugPrint('Error loading logs in parcel: $e');
    }
  }

  Future<void> _updateParcel(Parcel updatedParcel) async {
    setState(() => _isLoading = true);
    try {
      await _databaseService.updateParcel(updatedParcel);
      setState(() {
        _parcel = updatedParcel;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri posodabljanju: $e')));
      }
    }
  }

  Future<void> _exportParcel() async {
    try {
      await KmlService.exportParcelWithData(
        parcel: _parcel,
        logs: _logsInParcel,
        secnja: _secnjaInParcel,
        locations: _locationsInParcel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri izvozu: $e')));
      }
    }
  }

  Future<void> _editForestType() async {
    final result = await showDialog<ForestType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Vrsta gozda'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.deciduous),
            child: Row(
              children: [
                Icon(Icons.nature, color: Colors.green.shade600),
                const SizedBox(width: 16),
                const Text('Listavci'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.mixed),
            child: Row(
              children: [
                Icon(Icons.nature, size: 20, color: Colors.green.shade600),
                Icon(Icons.park, size: 20, color: Colors.green.shade800),
                const SizedBox(width: 12),
                const Text('Mešani gozd'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.coniferous),
            child: Row(
              children: [
                Icon(Icons.park, color: Colors.green.shade800),
                const SizedBox(width: 16),
                const Text('Iglavci'),
              ],
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateParcel(_parcel.copyWith(forestType: result));
    }
  }

  Future<void> _editOwner() async {
    final controller = TextEditingController(text: _parcel.owner ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lastnik'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ime lastnika',
            hintText: 'Vnesite ime lastnika',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Shrani'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateParcel(
        _parcel.copyWith(owner: result.isEmpty ? null : result),
      );
    }
  }

  Future<void> _editWoodAllowance() async {
    final controller = TextEditingController(
      text: _parcel.woodAllowance > 0 ? _parcel.woodAllowance.toString() : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dovoljen posek'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Kolicina (m³)',
            hintText: 'Vnesite dovoljeno kolicino',
            border: OutlineInputBorder(),
            suffixText: 'm³',
          ),
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? 0.0;
              Navigator.of(context).pop(value);
            },
            child: const Text('Shrani'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateParcel(_parcel.copyWith(woodAllowance: result));
    }
  }

  Future<void> _logWoodCut() async {
    final volumeController = TextEditingController();
    final treesController = TextEditingController(text: '1');

    final result = await showDialog<({double volume, int trees})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zabeleži posek'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trenutno posekano: ${_parcel.woodCut.toStringAsFixed(2)} m³',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_parcel.woodAllowance > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Se na voljo: ${_parcel.woodRemaining.toStringAsFixed(2)} m³',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.green),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: volumeController,
              decoration: const InputDecoration(
                labelText: 'Dodaj posek (m³)',
                hintText: 'Vnesite kolicino',
                border: OutlineInputBorder(),
                suffixText: 'm³',
              ),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: treesController,
              decoration: const InputDecoration(
                labelText: 'Stevilo dreves',
                hintText: 'Vnesite stevilo',
                border: OutlineInputBorder(),
                suffixText: 'dreves',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () {
              final volume = double.tryParse(volumeController.text) ?? 0.0;
              final trees = int.tryParse(treesController.text) ?? 0;
              Navigator.of(context).pop((volume: volume, trees: trees));
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result != null && result.volume > 0) {
      final newWoodCut = _parcel.woodCut + result.volume;
      final newTreesCut = _parcel.treesCut + result.trees;
      await _updateParcel(
        _parcel.copyWith(woodCut: newWoodCut, treesCut: newTreesCut),
      );

      if (mounted) {
        final message = result.trees > 0
            ? 'Dodano ${result.volume.toStringAsFixed(2)} m³ poseka (${result.trees} dreves)'
            : 'Dodano ${result.volume.toStringAsFixed(2)} m³ poseka';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _resetWoodCut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi posek'),
        content: const Text(
          'Ali ste prepricani, da zelite ponastaviti kolicino posekanega lesa na 0?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ponastavi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateParcel(_parcel.copyWith(woodCut: 0.0));
    }
  }

  Future<void> _logTreesCut() async {
    final controller = TextEditingController(text: '1');

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj posekana drevesa'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stevilo dreves',
            suffixText: 'dreves',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _updateParcel(
        _parcel.copyWith(treesCut: _parcel.treesCut + result),
      );
    }
  }

  Future<void> _resetTreesCut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi drevesa'),
        content: const Text(
          'Ali ste prepricani, da zelite ponastaviti stevilo posekanih dreves na 0?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ponastavi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateParcel(_parcel.copyWith(treesCut: 0));
    }
  }

  Future<void> _editPolygon() async {
    final result = await Navigator.of(context).push<Parcel>(
      MaterialPageRoute(
        builder: (context) => ParcelEditor(parcel: _parcel),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      // Preserve the existing metadata when updating polygon
      final updatedParcel = result.copyWith(
        owner: _parcel.owner,
        woodAllowance: _parcel.woodAllowance,
        woodCut: _parcel.woodCut,
        treesCut: _parcel.treesCut,
        cadastralMunicipality: _parcel.cadastralMunicipality,
        parcelNumber: _parcel.parcelNumber,
      );
      await _updateParcel(updatedParcel);
    }
  }

  Future<void> _deleteParcel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši parcelo'),
        content: Text(
          'Ali ste prepričani, da želite izbrisati "${_parcel.name}"?\n\n'
          'Izbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true && _parcel.id != null) {
      try {
        final deleted = await _databaseService.deleteParcelWithContents(
          _parcel.id!,
        );
        if (mounted) {
          final logsCount = deleted['logs'] ?? 0;
          final locationsCount = deleted['locations'] ?? 0;
          final extras = <String>[];
          if (logsCount > 0) extras.add('$logsCount hlodov');
          if (locationsCount > 0) extras.add('$locationsCount točk');
          final extraText = extras.isNotEmpty ? ' (${extras.join(', ')})' : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Parcela izbrisana$extraText')),
          );
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Napaka pri brisanju: $e')));
        }
      }
    }
  }

  /// Navigate to map with target point
  void _navigateToPoint(LatLng point, String name) {
    final target = NavigationTarget(location: point, name: name);

    // Pop back to main screen
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Use static method to navigate to map with target
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MainScreen.navigateToMapWithTarget(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. M. yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_parcel.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Uredi obliko',
            onPressed: _editPolygon,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportParcel();
              } else if (value == 'delete') {
                _deleteParcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Izvozi KML'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Izbriši', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parcel Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _editForestType,
                                child: _parcel.polygon.isNotEmpty
                                    ? ParcelSilhouette(
                                        polygon: _parcel.polygon,
                                        size: 72,
                                        fillColor: getForestTypeIcon(
                                          _parcel.forestType,
                                        ).$2.withValues(alpha: 0.3),
                                        strokeColor: getForestTypeIcon(
                                          _parcel.forestType,
                                        ).$2,
                                        strokeWidth: 2,
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: getForestTypeIcon(
                                            _parcel.forestType,
                                          ).$2.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          getForestTypeIcon(
                                            _parcel.forestType,
                                          ).$1,
                                          size: 32,
                                          color: getForestTypeIcon(
                                            _parcel.forestType,
                                          ).$2,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _parcel.areaFormatted,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      '${_parcel.polygon.length} tock',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
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
                            value: dateFormat.format(_parcel.createdAt),
                          ),
                          if (_parcel.isCadastral) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.location_city,
                              label: 'KO',
                              value: _parcel.cadastralMunicipality.toString(),
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.tag,
                              label: 'Parcela',
                              value: _parcel.parcelNumber!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Owner Card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Lastnik'),
                      subtitle: Text(_parcel.owner ?? 'Ni dolocen'),
                      trailing: const Icon(Icons.edit),
                      onTap: _editOwner,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Wood Tracking Card
                  Card(
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Allowance
                          InkWell(
                            onTap: _editWoodAllowance,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dovoljen posek',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        Text(
                                          _parcel.woodAllowance > 0
                                              ? '${_parcel.woodAllowance.toStringAsFixed(2)} m³'
                                              : 'Ni dolocen',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      '${_parcel.woodCut.toStringAsFixed(2)} m³',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.orange[700]),
                                    ),
                                  ],
                                ),
                              ),
                              if (_parcel.woodCut > 0)
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Ponastavi',
                                  onPressed: _resetWoodCut,
                                ),
                            ],
                          ),

                          // Progress bar if allowance is set
                          if (_parcel.woodAllowance > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _parcel.woodUsedPercent / 100,
                                minHeight: 12,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _parcel.woodUsedPercent >= 100
                                      ? Colors.red
                                      : _parcel.woodUsedPercent >= 80
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
                                  '${_parcel.woodUsedPercent.toStringAsFixed(0)}% izkorisceno',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Se na voljo: ${_parcel.woodRemaining.toStringAsFixed(2)} m³',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      '${_parcel.treesCut}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.green[700]),
                                    ),
                                  ],
                                ),
                              ),
                              if (_parcel.treesCut > 0)
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Ponastavi',
                                  onPressed: _resetTreesCut,
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _logWoodCut,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Posek m³'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _logTreesCut,
                                  icon: const Icon(Icons.nature),
                                  label: const Text('Drevo'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // See on map button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _navigateToPoint(_parcel.center, _parcel.name),
                      icon: const Icon(Icons.map),
                      label: const Text('Poglej na karti'),
                    ),
                  ),

                  // Logs Card (logs geolocated within parcel)
                  if (_logsInParcel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2,
                                  color: Colors.brown,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hlodovina na parceli (${_logsInParcel.length})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  '${_logsVolume.toStringAsFixed(2)} m³',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown[700],
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _logsInParcel.length > 5
                                ? 5
                                : _logsInParcel.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = _logsInParcel[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.circle,
                                    color: Colors.brown,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${log.volume.toStringAsFixed(4)} m³',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    if (log.diameter != null &&
                                        log.length != null)
                                      Text(
                                        'Ø ${log.diameter!.toStringAsFixed(0)} cm × ${log.length!.toStringAsFixed(1)} m',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Ročni vnos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    if (log.hasLocation) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.gps_fixed,
                                              size: 12,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'GPS',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: log.hasLocation
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.navigation,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Navigiraj',
                                        onPressed: () => _navigateToPoint(
                                          LatLng(log.latitude!, log.longitude!),
                                          'Hlod ${log.id}',
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          if (_logsInParcel.length > 5)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: Text(
                                  '... in še ${_logsInParcel.length - 5} hlodov',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Sečnja Card (trees marked for cutting within parcel)
                  if (_secnjaInParcel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.carpenter,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sečnja (${_secnjaInParcel.length})',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _secnjaInParcel.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final location = _secnjaInParcel[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.carpenter,
                                    color: Colors.deepOrange,
                                    size: 20,
                                  ),
                                ),
                                title: Text(location.name),
                                subtitle: Text(
                                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Navigiraj',
                                  onPressed: () => _navigateToPoint(
                                    LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    location.name,
                                  ),
                                ),
                                onTap: () => _navigateToPoint(
                                  LatLng(location.latitude, location.longitude),
                                  location.name,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Saved Locations Card (points saved within parcel)
                  if (_locationsInParcel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Shranjene tocke (${_locationsInParcel.length})',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _locationsInParcel.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final location = _locationsInParcel[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                title: Text(location.name),
                                subtitle: Text(
                                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Navigiraj',
                                  onPressed: () => _navigateToPoint(
                                    LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    location.name,
                                  ),
                                ),
                                onTap: () => _navigateToPoint(
                                  LatLng(location.latitude, location.longitude),
                                  location.name,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

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
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../router/app_router.dart';
import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../services/database_service.dart';
import '../services/kml_service.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/notes_editor_sheet.dart';
import '../widgets/parcel_info_widgets.dart';
import '../widgets/parcel_wood_tracking_card.dart';
import '../widgets/parcel_data_cards.dart';

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
    final newProvider = context.read<LogsProvider>();
    if (_logsProvider != newProvider) {
      _logsProvider?.removeListener(_onLogsChanged);
      _logsProvider = newProvider;
      _logsProvider?.addListener(_onLogsChanged);
    }
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
      if (!mounted) return;
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
    if (_parcel.id == 0) return;
    try {
      final logs = await _databaseService.getLogsByParcel(_parcel.id);
      final volume = await _databaseService.getParcelTotalVolume(_parcel.id);
      if (!mounted) return;
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

  Future<void> _editNotes() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          NotesEditorSheet(initialNotes: _parcel.notes, title: 'Opombe'),
    );

    if (result != null) {
      await _updateParcel(
        _parcel.copyWith(notes: result.isEmpty ? null : result),
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
    context.push(
      AppRoutes.parcelEdit(_parcel.id),
      extra: ParcelEditorParams(
        parcel: _parcel,
        onSave: (result) async {
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
        },
      ),
    );
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

    if (confirmed == true && _parcel.id != 0) {
      try {
        final deleted = await _databaseService.deleteParcelWithContents(
          _parcel.id,
        );
        // Notify map provider to refresh parcels, logs, and locations on map
        if (mounted) {
          final mapProvider = context.read<MapProvider>();
          mapProvider.loadParcels();
          mapProvider.loadGeolocatedLogs();
          mapProvider.loadLocations();
        }
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
          context.pop();
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

    // Set navigation target and switch to map
    context.read<NavigationNotifier>().navigateToMapWithTarget(target);
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
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
                  ParcelInfoCard(
                    parcel: _parcel,
                    onEditForestType: _editForestType,
                  ),

                  const SizedBox(height: 16),

                  // Owner Card
                  ParcelOwnerCard(owner: _parcel.owner, onEdit: _editOwner),

                  const SizedBox(height: 16),

                  // Notes Card
                  ParcelNotesCard(notes: _parcel.notes, onEdit: _editNotes),

                  const SizedBox(height: 16),

                  // Wood Tracking Card
                  ParcelWoodTrackingCard(
                    parcel: _parcel,
                    onEditAllowance: _editWoodAllowance,
                    onResetCut: _resetWoodCut,
                    onResetTrees: _resetTreesCut,
                    onLogWoodCut: _logWoodCut,
                    onLogTreesCut: _logTreesCut,
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
                    ParcelLogsCard(
                      logs: _logsInParcel,
                      totalVolume: _logsVolume,
                      onNavigateToPoint: _navigateToPoint,
                    ),
                  ],

                  // Sečnja Card (trees marked for cutting within parcel)
                  if (_secnjaInParcel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ParcelSecnjaCard(
                      secnja: _secnjaInParcel,
                      onNavigateToPoint: _navigateToPoint,
                    ),
                  ],

                  // Saved Locations Card (points saved within parcel)
                  if (_locationsInParcel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ParcelLocationsCard(
                      locations: _locationsInParcel,
                      onNavigateToPoint: _navigateToPoint,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

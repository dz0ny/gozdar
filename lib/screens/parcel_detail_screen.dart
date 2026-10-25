import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../router/app_router.dart';
import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../services/cadastral_service.dart';
import '../services/database_service.dart';
import '../services/kml_service.dart';
import '../services/map_preferences_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/parcel_pdf_service.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../utils/decimal_input.dart';
import '../widgets/navigate_to_sheet.dart';
import '../widgets/notes_editor_sheet.dart';
import '../widgets/parcel_info_widgets.dart';
import '../widgets/parcel_map_preview.dart';
import '../widgets/parcel_wood_tracking_card.dart';
import '../widgets/parcel_data_cards.dart';
import 'forest_tab.dart' show getForestTypeIcon;
import '../l10n/l10n.dart';

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
  OwnerInfo? _lookedUpOwner;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadLocationsInParcel();
    _loadLogsInParcel();
    _lookUpOwner();
  }

  /// Look up the owner/address (with občina) from the imported cadastral
  /// database. Runs for any cadastral parcel so the full address can be shown
  /// even when an owner name is already stored. Read-only; never modifies the
  /// parcel.
  void _lookUpOwner() {
    if (!_parcel.isCadastral || !OwnerLookupService.instance.isAvailable) return;
    final info = OwnerLookupService.instance.lookup(
      _parcel.cadastralMunicipality,
      _parcel.parcelNumber,
    );
    if (info != null && mounted) {
      setState(() => _lookedUpOwner = info);
    }
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
      // Refresh the map so the Karta tab reflects the edited polygon/name.
      if (mounted) {
        context.read<MapProvider>().loadParcels();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.parcelDetailUpdateError('$e'))));
      }
    }
  }

  /// Generate a PDF of this parcel (map snapshot + attributes) and open it.
  Future<void> _printParcel() async {
    final mapProvider = context.read<MapProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // PDF generation fetches map tiles and is slow; show progress feedback
    // since the popup menu has already closed.
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(context.l10n.parcelDetailPreparingPdf),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );
    final cadastral = CadastralParcel(
      id: _parcel.cadastralId ?? '',
      cadastralMunicipality: _parcel.cadastralMunicipality ?? 0,
      parcelNumber: _parcel.parcelNumber ?? _parcel.name,
      area: _parcel.areaM2,
      polygon: _parcel.polygon,
    );
    try {
      final bytes = await ParcelPdfService.instance.buildParcelPdf(
        parcel: cadastral,
        baseLayer: mapProvider.currentBaseLayer,
        activeOverlays: mapProvider.activeOverlays,
        workerUrl:
            mapProvider.workerUrl ?? MapPreferencesService.defaultWorkerUrl,
      );
      final safeName = (cadastral.parcelNumber.isNotEmpty
              ? cadastral.parcelNumber
              : _parcel.name)
          .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '-');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/parcela-$safeName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      messenger.hideCurrentSnackBar();
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(L10n.current.parcelDetailPdfOpenError(result.message))),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(L10n.current.parcelDetailPdfError('$e'))),
        );
      }
    }
  }

  Future<void> _exportParcel() async {
    final messenger = ScaffoldMessenger.of(context);
    // Export can be slow; show progress since the popup menu has closed.
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(context.l10n.parcelDetailPreparingExport),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );
    try {
      await KmlService.exportParcelWithData(
        parcel: _parcel,
        logs: _logsInParcel,
        secnja: _secnjaInParcel,
        locations: _locationsInParcel,
      );
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(L10n.current.parcelDetailExportDone)),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(L10n.current.parcelDetailExportError('$e'))),
        );
      }
    }
  }

  Future<void> _editForestType() async {
    final result = await showDialog<ForestType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.parcelForestTypeTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.deciduous),
            child: Row(
              children: [
                Icon(Icons.nature, color: Colors.green.shade600),
                const SizedBox(width: 16),
                Text(context.l10n.parcelForestTypeDeciduous),
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
                Text(context.l10n.parcelForestTypeMixed),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.coniferous),
            child: Row(
              children: [
                Icon(Icons.park, color: Colors.green.shade800),
                const SizedBox(width: 16),
                Text(context.l10n.parcelForestTypeConiferous),
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
        title: Text(context.l10n.parcelOwnerTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.parcelOwnerNameLabel,
            hintText: context.l10n.parcelOwnerNameHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateParcel(
        result.isEmpty
            ? _parcel.copyWith(clearOwner: true)
            : _parcel.copyWith(owner: result),
      );
    }
  }

  Future<void> _editNotes() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          NotesEditorSheet(initialNotes: _parcel.notes, title: context.l10n.parcelNotesTitle),
    );

    if (result != null) {
      await _updateParcel(
        result.isEmpty
            ? _parcel.copyWith(clearNotes: true)
            : _parcel.copyWith(notes: result),
      );
    }
  }

  Future<void> _editWoodAllowance() async {
    final controller = TextEditingController(
      text: _parcel.woodAllowance > 0 ? _parcel.woodAllowance.toString() : '',
    );

    String? errorText;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(context.l10n.parcelAllowanceTitle),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.l10n.parcelAllowanceAmountLabel,
                hintText: context.l10n.parcelAllowanceAmountHint,
                border: const OutlineInputBorder(),
                suffixText: 'm³',
                errorText: errorText,
              ),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalTextInputFormatter()],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    Navigator.of(context).pop(0.0);
                    return;
                  }
                  final value = parseDecimal(text);
                  if (value == null) {
                    setDialogState(
                      () => errorText = context.l10n.parcelInvalidNumber,
                    );
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: Text(context.l10n.commonSave),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await _updateParcel(_parcel.copyWith(woodAllowance: result));
    }
  }

  Future<void> _logWoodCut() async {
    final volumeController = TextEditingController();
    final treesController = TextEditingController(text: '1');

    final result = await showDialog<({double? volume, int trees})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.parcelLogCutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.parcelCutCurrent(_parcel.woodCut.toStringAsFixed(2)),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_parcel.woodAllowance > 0) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.parcelCutRemaining(_parcel.woodRemaining.toStringAsFixed(2)),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.green),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: volumeController,
              decoration: InputDecoration(
                labelText: context.l10n.parcelCutAddLabel,
                hintText: context.l10n.parcelCutAddHint,
                border: const OutlineInputBorder(),
                suffixText: 'm³',
              ),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalTextInputFormatter()],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: treesController,
              decoration: InputDecoration(
                labelText: context.l10n.parcelTreesCountLabel,
                hintText: context.l10n.parcelTreesCountHint,
                border: const OutlineInputBorder(),
                suffixText: context.l10n.parcelTreesUnit,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final volume = parseDecimal(volumeController.text);
              final trees = int.tryParse(treesController.text) ?? 0;
              Navigator.of(context).pop((volume: volume, trees: trees));
            },
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    );

    if (result == null) return;

    final volume = result.volume;
    if (volume == null || volume <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.parcelCutInvalidAmount)),
        );
      }
      return;
    }

    final newWoodCut = _parcel.woodCut + volume;
    final newTreesCut = _parcel.treesCut + result.trees;
    await _updateParcel(
      _parcel.copyWith(woodCut: newWoodCut, treesCut: newTreesCut),
    );

    if (mounted) {
      final message = result.trees > 0
          ? context.l10n.parcelCutAddedWithTrees(
              volume.toStringAsFixed(2),
              result.trees,
            )
          : context.l10n.parcelCutAdded(volume.toStringAsFixed(2));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _resetWoodCut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.parcelResetCutTitle),
        content: Text(context.l10n.parcelResetCutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.l10n.parcelReset),
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
        title: Text(context.l10n.parcelAddTreesTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10n.parcelTreesCountLabel,
            suffixText: context.l10n.parcelTreesUnit,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.of(context).pop(value);
            },
            child: Text(context.l10n.commonAdd),
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
        title: Text(context.l10n.parcelResetTreesTitle),
        content: Text(context.l10n.parcelResetTreesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.l10n.parcelReset),
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
          // ParcelEditor copies the existing parcel, so owner/notes/cadastral/
          // wood fields and point names are already preserved.
          await _updateParcel(result);
        },
      ),
    );
  }

  Future<void> _deleteParcel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.parcelDeleteTitle),
        content: Text(context.l10n.parcelDeleteMessage(_parcel.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
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
          final l10n = context.l10n;
          if (logsCount > 0) extras.add(l10n.parcelDeletedLogsExtra(logsCount));
          if (locationsCount > 0) {
            extras.add(l10n.parcelDeletedPointsExtra(locationsCount));
          }
          final message = extras.isNotEmpty
              ? l10n.parcelDeletedWithExtras(extras.join(', '))
              : l10n.parcelDeleted;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.parcelDeleteError('$e'))));
        }
      }
    }
  }

  /// Show [point] on the map; with [startNavigation] the compass opens too.
  void _navigateToPoint(
    LatLng point,
    String name, {
    bool startNavigation = false,
  }) {
    final target = NavigationTarget(
      location: point,
      name: name,
      startNavigation: startNavigation,
    );

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
            tooltip: context.l10n.parcelEditShape,
            onPressed: _editPolygon,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'print') {
                _printParcel();
              } else if (value == 'export') {
                _exportParcel();
              } else if (value == 'delete') {
                _deleteParcel();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    const Icon(Icons.print),
                    const SizedBox(width: 8),
                    Text(context.l10n.parcelPrint),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: 8),
                    Text(context.l10n.parcelExportKml),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.commonDelete,
                      style: const TextStyle(color: Colors.red),
                    ),
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
                  // Embedded map preview (uses the main map's current layers)
                  if (_parcel.polygon.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final mapProvider = context.watch<MapProvider>();
                        return ParcelMapPreview(
                          polygon: _parcel.polygon,
                          baseLayer: mapProvider.currentBaseLayer,
                          activeOverlays: mapProvider.activeOverlays,
                          workerUrl: mapProvider.workerUrl,
                          outlineColor:
                              getForestTypeIcon(_parcel.forestType).$2,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Parcel Info Card
                  ParcelInfoCard(
                    parcel: _parcel,
                    onEditForestType: _editForestType,
                  ),

                  const SizedBox(height: 16),

                  // Owner Card
                  ParcelOwnerCard(
                    owner: _parcel.owner,
                    onEdit: _editOwner,
                    lookedUpOwner: _lookedUpOwner?.displayOwners,
                    lookedUpAddress: _lookedUpOwner?.address,
                  ),

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

                  // See on map / navigate buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _navigateToPoint(_parcel.center, _parcel.name),
                          icon: const Icon(Icons.map),
                          label: Text(context.l10n.parcelViewOnMap),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => NavigateToSheet.show(
                            context,
                            destination: _parcel.center,
                            name: _parcel.name,
                            onInAppNavigation: () => _navigateToPoint(
                              _parcel.center,
                              _parcel.name,
                              startNavigation: true,
                            ),
                          ),
                          icon: const Icon(Icons.navigation),
                          label: Text(context.l10n.parcelNavigate),
                        ),
                      ),
                    ],
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

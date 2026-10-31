import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../router/app_router.dart';
import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../services/hr_owner_service.dart';
import '../services/cadastral_service.dart';
import '../services/database_service.dart';
import '../models/map_layer.dart';
import '../services/drone_bundle_service.dart';
import '../services/drone_align_service.dart';
import '../services/drone_mission_service.dart';
import '../services/drone_mosaic_service.dart';
import '../services/drone_photo_service.dart';
import '../services/drone_settings.dart';
import '../services/kml_service.dart';
import '../services/map_preferences_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/si_valuation_service.dart';
import '../services/auction_service.dart';
import '../widgets/auction_sheet.dart';
import '../services/parcel_pdf_service.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../utils/decimal_input.dart';
import '../utils/formats.dart';
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

  /// GURS value of a Slovenian cadastral parcel; null elsewhere.
  Future<ParcelValuation?>? _valuation;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadLocationsInParcel();
    _loadLogsInParcel();
    _lookUpOwner();
    _lookUpValuation();
    _loadMosaic();
  }

  /// Look up the owner/address (with občina) from the imported cadastral
  /// database. Runs for any cadastral parcel so the full address can be shown
  /// even when an owner name is already stored. Read-only; never modifies the
  /// parcel.
  void _lookUpOwner() {
    if (!_parcel.isCadastral) return;
    final ko = _parcel.cadastralMunicipality;
    final number = _parcel.parcelNumber;
    if (HrOwnerService.isCroatianKo(ko)) {
      // Croatian holders (with shares) come live from the DGU cadastre.
      HrOwnerService.instance.lookup(ko!, number!).then((info) {
        if (info != null && mounted) setState(() => _lookedUpOwner = info);
      });
      return;
    }
    if (!OwnerLookupService.instance.isAvailable) return;
    final info = OwnerLookupService.instance.lookup(ko, number);
    if (info != null && mounted) {
      setState(() => _lookedUpOwner = info);
    }
  }

  void _lookUpValuation() {
    final ko = _parcel.cadastralMunicipality;
    if (!_parcel.isCadastral || !SiValuationService.covers(ko)) return;
    _valuation = SiValuationService.instance.lookup(ko!, _parcel.parcelNumber!);
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

  /// Exports a lawnmower survey mission (DJI WPML KMZ) covering the parcel.
  Future<void> _exportDroneMission() async {
    final messenger = ScaffoldMessenger.of(context);
    const options = DroneMissionOptions();
    final svc = DroneMissionService.instance;
    final waypoints = svc.planGrid(_parcel.polygon, options);
    if (waypoints.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Parcela nima veljavne oblike.')),
      );
      return;
    }
    try {
      final bytes = svc.buildKmz(
        name: _parcel.name,
        waypoints: waypoints,
        options: options,
      );
      final safeName = _parcel.name.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '-');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/polet-$safeName.kmz');
      await file.writeAsBytes(bytes, flush: true);
      final km = svc.pathLengthM(waypoints) / 1000;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Načrt poleta ${_parcel.name}',
          text:
              '${waypoints.length} točk, ${km.toStringAsFixed(1)} km, '
              '${options.altitudeM.round()} m',
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Napaka pri izvozu poleta: $e')),
        );
      }
    }
  }

  Directory? _mosaicDir;
  DroneMosaic? _mosaic;

  Future<Directory> _mosaicDirectory() async {
    final base = await getApplicationSupportDirectory();
    return _mosaicDir ??= Directory(
      '${base.path}/drone_mosaics/${_parcel.id}',
    );
  }

  Future<void> _loadMosaic() async {
    if (!DroneSettings.instance.enabled) return;
    final mosaic = await DroneMosaicService.instance.load(
      await _mosaicDirectory(),
    );
    if (mounted && mosaic != null) setState(() => _mosaic = mosaic);
  }

  /// Picks many photos and keeps those that touch this parcel.
  Future<PhotoScan?> _pickAndScanPhotos() async {
    // iOS: the photo gallery, asking for the original file so the GPS and
    // DJI gimbal metadata survive. Android: the file picker, because its
    // photo picker strips the location from photos.
    final picked = Platform.isIOS
        ? await FilePicker.pickFiles(
            type: FileType.image,
            darwinOptions: const DarwinOptions(
              assetRepresentationMode: DarwinAssetRepresentationMode.current,
            ),
          )
        : await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg'],
          );
    if (picked.isEmpty || !mounted) return null;
    final files = [
      for (final f in picked)
        if (f.path != null) File(f.path!),
    ];
    final progress = ValueNotifier<String>('Berem metapodatke …');
    _showProgress(progress);
    try {
      final scan = await DronePhotoService.instance.readAll(
        files,
        _parcel.polygon,
        onProgress: (done, total) =>
            progress.value = 'Fotografije $done / $total',
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Na parceli: ${scan.inside.length} od ${scan.total}. '
            'Preskočeno: ${scan.outside} zunaj parcele, '
            '${scan.notNadir} ne navpično, '
            '${scan.unreadable} brez GPS podatkov.',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      return scan;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      rethrow;
    }
  }

  void _showProgress(ValueNotifier<String> text) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: text,
            builder: (_, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Puts the photos on the ground by GPS and heading. This is a preview.
  Future<void> _buildMosaic() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final scan = await _pickAndScanPhotos();
      if (scan == null || !mounted) return;
      if (scan.inside.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nobena fotografija ni na parceli.')),
        );
        return;
      }
      final progress = ValueNotifier<String>('Sestavljam mozaik …');
      _showProgress(progress);
      DroneMosaic? saved;
      String? alignNote;
      try {
        var photos = scan.inside;
        try {
          final (aligned, result) = await DroneAlignService.instance.align(
            photos,
            _parcel.polygon,
            onProgress: (m) => progress.value = m,
          );
          photos = aligned;
          if (result != null) {
            alignNote =
                'Poravnava: ${result.pairsUsed} od ${result.pairsTried} parov.';
          }
        } catch (_) {
          alignNote = 'Poravnava ni uspela, uporabljen je GPS.';
        }
        final image = await DroneMosaicService.instance.render(
          photos,
          _parcel.polygon,
          onProgress: (done, total) =>
              progress.value = 'Mozaik: fotografija $done / $total',
        );
        if (image != null) {
          saved = await DroneMosaicService.instance.save(
            await _mosaicDirectory(),
            image,
            scan.inside.length,
          );
        }
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      if (saved == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Mozaika ni mogoče sestaviti.')),
        );
        return;
      }
      imageCache.clear();
      setState(() => _mosaic = saved);
      if (alignNote != null) {
        messenger.showSnackBar(SnackBar(content: Text(alignNote)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Napaka pri mozaiku: $e')),
        );
      }
    }
  }

  /// Builds a ZIP with the plan, the boundary, the orthophoto and the photos.
  Future<void> _exportDroneBundle() async {
    final messenger = ScaffoldMessenger.of(context);
    final mapProvider = context.read<MapProvider>();
    const options = DroneMissionOptions();
    final svc = DroneMissionService.instance;
    final waypoints = svc.planGrid(_parcel.polygon, options);
    if (waypoints.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Parcela nima veljavne oblike.')),
      );
      return;
    }

    final attach = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paket za dron'),
        content: const Text(
          'Paket vsebuje načrt poleta, mejo parcele in referenčni ortofoto. '
          'Želite dodati tudi fotografije z drona (JPG/DNG s GPS podatki)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Brez fotografij'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dodaj fotografije'),
          ),
        ],
      ),
    );
    if (attach == null || !mounted) return;

    var photos = <File>[];
    if (attach) {
      final scan = await _pickAndScanPhotos();
      if (scan == null || !mounted) return;
      photos = [for (final ph in scan.inside) ph.file];
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pripravljam paket …'),
        duration: Duration(minutes: 2),
      ),
    );
    try {
      final workerUrl =
          mapProvider.workerUrl ?? MapPreferencesService.defaultWorkerUrl;
      // Prefer the national orthophoto; fall back to the current base layer
      // where it has no Web Mercator tile URL (e.g. outside Slovenia).
      final orthoLayer =
          MapLayer.ortofoto.resolveUrlTemplate(workerUrl) != null
              ? MapLayer.ortofoto
              : mapProvider.currentBaseLayer;
      final ortho = await ParcelPdfService.instance.renderReferenceImage(
        polygon: _parcel.polygon,
        baseLayer: orthoLayer,
        workerUrl: workerUrl,
      );
      final kmz = svc.buildKmz(
        name: _parcel.name,
        waypoints: waypoints,
        options: options,
      );
      final safeName = _parcel.name.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '-');
      final dir = await getTemporaryDirectory();
      final file = await DroneBundleService.instance.writeBundle(
        outPath: '${dir.path}/paket-$safeName.zip',
        parcelName: _parcel.name,
        cadastralId: _parcel.cadastralId,
        polygon: _parcel.polygon,
        options: options,
        waypoints: waypoints,
        kmz: kmz,
        referenceOrtho: ortho,
        photos: photos,
      );
      messenger.hideCurrentSnackBar();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Paket za dron ${_parcel.name}',
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Napaka pri pripravi paketa: $e')),
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
                Icon(Icons.park, size: 20, color: Colors.green.shade300),
                const SizedBox(width: 12),
                Text(context.l10n.parcelForestTypeMixed),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(ForestType.coniferous),
            child: Row(
              children: [
                Icon(Icons.park, color: Colors.green.shade300),
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
              context.l10n.parcelCutCurrent(Fmt.num(_parcel.woodCut, 2)),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_parcel.woodAllowance > 0) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.parcelCutRemaining(Fmt.num(_parcel.woodRemaining, 2)),
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
              Fmt.num(volume, 2),
              result.trees,
            )
          : context.l10n.parcelCutAdded(Fmt.num(volume, 2));
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

  /// "Poglej na karti" (outlined) and "Navigiraj" (filled).
  Widget _buildMapActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _navigateToPoint(_parcel.center, _parcel.name),
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
    );
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
              } else if (value == 'drone') {
                _exportDroneMission();
              } else if (value == 'drone_bundle') {
                _exportDroneBundle();
              } else if (value == 'drone_mosaic') {
                _buildMosaic();
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
              if (DroneSettings.instance.enabled)
                const PopupMenuItem(
                  value: 'drone',
                  child: Row(
                    children: [
                      Icon(Icons.flight),
                      SizedBox(width: 8),
                      Text('Načrt poleta (dron)'),
                    ],
                  ),
                ),
              if (DroneSettings.instance.enabled)
                const PopupMenuItem(
                  value: 'drone_bundle',
                  child: Row(
                    children: [
                      Icon(Icons.folder_zip_outlined),
                      SizedBox(width: 8),
                      Text('Paket za dron (ZIP)'),
                    ],
                  ),
                ),
              if (DroneSettings.instance.enabled)
                const PopupMenuItem(
                  value: 'drone_mosaic',
                  child: Row(
                    children: [
                      Icon(Icons.grid_on),
                      SizedBox(width: 8),
                      Text('Mozaik iz fotografij'),
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
                  // Capped height so the key facts and actions stay above
                  // the fold.
                  if (_parcel.polygon.isNotEmpty) ...[
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Builder(
                        builder: (context) {
                          final mapProvider = context.watch<MapProvider>();
                          return ParcelMapPreview(
                            polygon: _parcel.polygon,
                            baseLayer: mapProvider.currentBaseLayer,
                            activeOverlays: mapProvider.activeOverlays,
                            workerUrl: mapProvider.workerUrl,
                            outlineColor:
                                getForestTypeIcon(_parcel.forestType).$2,
                            mosaic: _mosaic,
                            fill: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // The most used actions, right under the map: one filled
                  // primary, the other outlined.
                  _buildMapActions(context),
                  const SizedBox(height: 16),

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
                    lookedUp: _lookedUpOwner,
                  ),

                  const SizedBox(height: 16),

                  // Brings its own bottom gap, so nothing is left when
                  // GURS has no answer.
                  if (_valuation != null)
                    ParcelValuationCard(valuation: _valuation!),

                  // A "Na dražbi" card when the parcel is up for sale.
                  if (_valuation != null)
                    FutureBuilder<List<Auction>>(
                      future: AuctionService.instance.forParcel(
                        _parcel.cadastralMunicipality!,
                        _parcel.parcelNumber!,
                      ),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? const [];
                        if (list.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                              child: Column(
                                children: [
                                  for (final a in list) AuctionLine(auction: a),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

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

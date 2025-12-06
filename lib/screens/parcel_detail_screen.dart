import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/navigation_target.dart';
import '../services/database_service.dart';
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
  List<MapLocation> _locationsInParcel = [];

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadLocationsInParcel();
  }

  Future<void> _loadLocationsInParcel() async {
    try {
      final allLocations = await _databaseService.getAllLocations();
      setState(() {
        _locationsInParcel = allLocations
            .where((loc) => _parcel.containsPoint(LatLng(loc.latitude, loc.longitude)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading locations in parcel: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri posodabljanju: $e')),
        );
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
      await _updateParcel(_parcel.copyWith(owner: result.isEmpty ? null : result));
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
    final controller = TextEditingController();

    final result = await showDialog<double>(
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Dodaj posek (m³)',
                hintText: 'Vnesite kolicino',
                border: OutlineInputBorder(),
                suffixText: 'm³',
              ),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              final value = double.tryParse(controller.text) ?? 0.0;
              Navigator.of(context).pop(value);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      final newWoodCut = _parcel.woodCut + result;
      await _updateParcel(_parcel.copyWith(woodCut: newWoodCut));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dodano ${result.toStringAsFixed(2)} m³ poseka'),
          ),
        );
      }
    }
  }

  Future<void> _resetWoodCut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi posek'),
        content: const Text('Ali ste prepricani, da zelite ponastaviti kolicino posekanega lesa na 0?'),
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
      await _updateParcel(_parcel.copyWith(treesCut: _parcel.treesCut + result));
    }
  }

  Future<void> _resetTreesCut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ponastavi drevesa'),
        content: const Text('Ali ste prepricani, da zelite ponastaviti stevilo posekanih dreves na 0?'),
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
        title: const Text('Izbrisi parcelo'),
        content: Text('Ali ste prepricani, da zelite izbrisati "${_parcel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Preklici'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Izbrisi'),
          ),
        ],
      ),
    );

    if (confirmed == true && _parcel.id != null) {
      try {
        await _databaseService.deleteParcel(_parcel.id!);
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri brisanju: $e')),
          );
        }
      }
    }
  }

  /// Navigate to map with target point
  void _navigateToPoint(LatLng point, String name) {
    // Get the main screen state before popping
    final mainState = context.findAncestorStateOfType<MainScreenState>();
    // Pop back to main screen
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Navigate to map with target after frame
    if (mainState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mainState.setNavigationTarget(NavigationTarget(location: point, name: name));
      });
    }
  }

  /// Edit point name dialog
  Future<void> _editPointName(int index) async {
    final currentName = _parcel.pointNames.length > index ? _parcel.pointNames[index] : null;
    final controller = TextEditingController(text: currentName ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Poimenuj tocko ${index + 1}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Ime tocke',
            hintText: 'Tocka ${index + 1}',
            border: const OutlineInputBorder(),
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
      final updatedParcel = _parcel.withPointName(index, result.isEmpty ? null : result);
      await _updateParcel(updatedParcel);
    }
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
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Izbrisi',
            onPressed: _deleteParcel,
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
                                        fillColor: getForestTypeIcon(_parcel.forestType).$2.withValues(alpha: 0.3),
                                        strokeColor: getForestTypeIcon(_parcel.forestType).$2,
                                        strokeWidth: 2,
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: getForestTypeIcon(_parcel.forestType).$2.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          getForestTypeIcon(_parcel.forestType).$1,
                                          size: 32,
                                          color: getForestTypeIcon(_parcel.forestType).$2,
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
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      '${_parcel.polygon.length} tock',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dovoljen posek',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        Text(
                                          _parcel.woodAllowance > 0
                                              ? '${_parcel.woodAllowance.toStringAsFixed(2)} m³'
                                              : 'Ni dolocen',
                                          style: Theme.of(context).textTheme.titleLarge,
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
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                    Text(
                                      '${_parcel.woodCut.toStringAsFixed(2)} m³',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.orange[700],
                                          ),
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
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                    Text(
                                      '${_parcel.treesCut}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Colors.green[700],
                                          ),
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

                  // Boundary Points Card (parcel polygon vertices) - collapsible
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const Icon(Icons.pentagon_outlined, color: Colors.green),
                      title: Text(
                        'Mejne tocke (${_parcel.polygon.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      initiallyExpanded: false,
                      children: [
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _parcel.polygon.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final point = _parcel.polygon[index];
                            final pointName = _parcel.getPointName(index);
                            final hasCustomName = _parcel.pointNames.length > index && _parcel.pointNames[index] != null;
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(pointName)),
                                  IconButton(
                                    icon: Icon(
                                      hasCustomName ? Icons.edit : Icons.edit_outlined,
                                      size: 18,
                                      color: hasCustomName ? Colors.green : Colors.grey,
                                    ),
                                    tooltip: 'Poimenuj',
                                    onPressed: () => _editPointName(index),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.navigation, color: Colors.blue),
                                tooltip: 'Navigiraj',
                                onPressed: () => _navigateToPoint(point, pointName),
                              ),
                              onTap: () => _navigateToPoint(point, pointName),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

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
                                const Icon(Icons.location_on, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'Shranjene tocke (${_locationsInParcel.length})',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _locationsInParcel.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final location = _locationsInParcel[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.place, color: Colors.red, size: 20),
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
                                  icon: const Icon(Icons.navigation, color: Colors.blue),
                                  tooltip: 'Navigiraj',
                                  onPressed: () => _navigateToPoint(
                                    LatLng(location.latitude, location.longitude),
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
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

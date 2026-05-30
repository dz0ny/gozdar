import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/parcel.dart';
import '../providers/map_provider.dart';
import '../services/cadastral_service.dart';
import '../services/database_service.dart';
import '../services/owner_lookup_service.dart';

enum _ImportState { idle, importing, imported, exists, notFound, error }

/// Search the imported GURS owners database by name and/or address, then import
/// the cadastral parcel (KO + parcela) for any result into "Moj gozd".
class OwnerImportSearchScreen extends StatefulWidget {
  const OwnerImportSearchScreen({super.key});

  @override
  State<OwnerImportSearchScreen> createState() =>
      _OwnerImportSearchScreenState();
}

class _OwnerImportSearchScreenState extends State<OwnerImportSearchScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _databaseService = DatabaseService();
  final _cadastralService = CadastralService();

  Timer? _debounce;
  List<OwnerSearchHit> _hits = const [];
  bool _truncated = false;
  final Map<String, _ImportState> _status = {};

  static const _limit = 300;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _key(OwnerSearchHit h) => '${h.sifko}/${h.parcela}';

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _runSearch() {
    final hits = OwnerLookupService.instance.searchOwners(
      name: _nameController.text,
      address: _addressController.text,
      limit: _limit,
    );
    setState(() {
      _hits = hits;
      _truncated = hits.length >= _limit;
    });
  }

  Future<void> _import(OwnerSearchHit hit) async {
    final key = _key(hit);
    setState(() => _status[key] = _ImportState.importing);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Already imported?
      final existing = await _databaseService.findParcelByKoAndNumber(
        hit.sifko,
        hit.parcela,
      );
      if (existing != null) {
        if (!mounted) return;
        setState(() => _status[key] = _ImportState.exists);
        messenger.showSnackBar(
          SnackBar(content: Text('Parcela ${hit.parcela} je že uvožena.')),
        );
        return;
      }

      // Fetch geometry from the cadastral WFS (owners DB has no geometry).
      final wfs = await _cadastralService.queryParcelByKoAndNumber(
        hit.sifko.toString(),
        hit.parcela,
      );
      if (wfs == null || wfs.polygon.isEmpty) {
        if (!mounted) return;
        setState(() => _status[key] = _ImportState.notFound);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Geometrije za ${hit.parcela} ni bilo mogoče najti.'),
          ),
        );
        return;
      }

      final parcel = Parcel(
        name: '${hit.sifko} - ${hit.parcela}',
        polygon: wfs.polygon,
        cadastralMunicipality: hit.sifko,
        parcelNumber: hit.parcela,
        owner: hit.owner,
        createdAt: DateTime.now(),
      );
      await _databaseService.insertParcel(parcel);
      if (mounted) {
        context.read<MapProvider>().loadParcels();
      }

      if (!mounted) return;
      setState(() => _status[key] = _ImportState.imported);
      messenger.showSnackBar(
        SnackBar(content: Text('Uvožena parcela ${hit.parcela}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status[key] = _ImportState.error);
      messenger.showSnackBar(
        SnackBar(content: Text('Uvoz ni uspel: $e')),
      );
    }
  }

  Widget _trailingFor(OwnerSearchHit hit) {
    final state = _status[_key(hit)] ?? _ImportState.idle;
    switch (state) {
      case _ImportState.importing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _ImportState.imported:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _ImportState.exists:
        return Icon(Icons.library_add_check,
            color: Theme.of(context).colorScheme.onSurfaceVariant);
      case _ImportState.notFound:
      case _ImportState.error:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Poskusi znova',
          onPressed: () => _import(hit),
        );
      case _ImportState.idle:
        return IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Uvozi parcelo',
          onPressed: () => _import(hit),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Uvoz po lastniku')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => _onQueryChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Ime lastnika',
                    prefixIcon: Icon(Icons.person_search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => _onQueryChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Naslov',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          if (_truncated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prikazanih prvih $_limit zadetkov — natančneje določi iskanje.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasQuery = _nameController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty;
    if (!hasQuery) {
      return _hint(
        Icons.search,
        'Vnesi ime lastnika in/ali naslov za iskanje parcel.',
      );
    }
    if (_hits.isEmpty) {
      return _hint(Icons.person_off, 'Ni zadetkov.');
    }
    return ListView.separated(
      itemCount: _hits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final hit = _hits[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.landscape, color: cs.onPrimaryContainer),
          ),
          title: Text(
            'KO ${hit.koLabel} • Parcela ${hit.parcela}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hit.owner),
              if (hit.address != null)
                Text(
                  hit.address!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          isThreeLine: hit.address != null,
          trailing: _trailingFor(hit),
        );
      },
    );
  }

  Widget _hint(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

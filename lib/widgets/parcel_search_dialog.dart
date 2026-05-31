import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/parcel_search_history_service.dart';

/// Bottom sheet for searching cadastral parcels. Always offers search by KO
/// number + parcel number. When an owners database is imported, a second tab
/// lets the user search by owner name and/or address; selecting a result
/// fetches the parcel geometry and reuses the same [onParcelFound] flow.
class ParcelSearchDialog extends StatefulWidget {
  final MapController mapController;
  final Function(WfsParcel) onParcelFound;

  const ParcelSearchDialog({
    super.key,
    required this.mapController,
    required this.onParcelFound,
  });

  @override
  State<ParcelSearchDialog> createState() => _ParcelSearchDialogState();

  static Future<void> show({
    required BuildContext context,
    required MapController mapController,
    required Function(WfsParcel) onParcelFound,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ParcelSearchDialog(
          mapController: mapController,
          onParcelFound: onParcelFound,
        ),
      ),
    );
  }
}

class _ParcelSearchDialogState extends State<ParcelSearchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _koController = TextEditingController();
  final _parcelController = TextEditingController();
  final _cadastralService = CadastralService();
  final _historyService = ParcelSearchHistoryService();
  bool _isSearching = false;
  String? _errorMessage;
  List<String> _koHistory = [];
  List<String> _parcelHistory = [];

  // Owner-search tab state (only used when the owners DB is available).
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  Timer? _ownerDebounce;
  List<OwnerSearchHit> _ownerHits = const [];
  bool _ownerTruncated = false;
  String? _locatingKey;
  String? _ownerError;

  static const _ownerLimit = 300;

  bool get _ownersAvailable => OwnerLookupService.instance.isAvailable;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Load search history for autocomplete
  Future<void> _loadHistory() async {
    final koHistory = await _historyService.getKoHistory();
    final parcelHistory = await _historyService.getParcelHistory();
    if (mounted) {
      setState(() {
        _koHistory = koHistory;
        _parcelHistory = parcelHistory;
      });
    }
  }

  @override
  void dispose() {
    _koController.dispose();
    _parcelController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _ownerDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchParcel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final koNumber = _koController.text.trim();
      final parcelNumber = _parcelController.text.trim();

      final parcel = await _cadastralService.queryParcelByKoAndNumber(
        koNumber,
        parcelNumber,
      );

      if (!mounted) return;

      if (parcel != null && parcel.polygon.isNotEmpty) {
        // Save to search history
        await _historyService.addKoToHistory(koNumber);
        await _historyService.addParcelToHistory(parcelNumber);

        if (!mounted) return;

        // Close dialog
        Navigator.of(context).pop();

        // Call callback to handle parcel display
        widget.onParcelFound(parcel);
      } else {
        setState(() {
          _errorMessage = 'Parcela ni najdena';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Napaka pri iskanju: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  String _ownerKey(OwnerSearchHit h) => '${h.sifko}/${h.parcela}';

  void _onOwnerQueryChanged() {
    _ownerDebounce?.cancel();
    _ownerDebounce = Timer(const Duration(milliseconds: 300), _runOwnerSearch);
  }

  void _runOwnerSearch() {
    final hits = OwnerLookupService.instance.searchOwners(
      name: _nameController.text,
      address: _addressController.text,
      limit: _ownerLimit,
    );
    if (!mounted) return;
    setState(() {
      _ownerHits = hits;
      _ownerTruncated = hits.length >= _ownerLimit;
    });
  }

  /// Fetch the parcel geometry for an owner hit and hand it to the map. The
  /// owners DB has no geometry, so we query the cadastral WFS by KO + parcela.
  Future<void> _locateOwnerHit(OwnerSearchHit hit) async {
    final key = _ownerKey(hit);
    setState(() {
      _locatingKey = key;
      _ownerError = null;
    });

    try {
      final parcel = await _cadastralService.queryParcelByKoAndNumber(
        hit.sifko.toString(),
        hit.parcela,
      );

      if (!mounted) return;

      if (parcel != null && parcel.polygon.isNotEmpty) {
        Navigator.of(context).pop();
        widget.onParcelFound(parcel);
      } else {
        setState(() {
          _locatingKey = null;
          _ownerError =
              'Geometrije za parcelo ${hit.parcela} ni bilo mogoče najti.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locatingKey = null;
        _ownerError = 'Napaka pri iskanju: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownersAvailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handleBar(),
          _title('Iskanje parcele', Icons.search),
          _buildParcelForm(context),
        ],
      );
    }

    // Tabbed layout: parcel search + owner search.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handleBar(),
          _title('Iskanje', Icons.search),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: 'Parcela'),
              Tab(icon: Icon(Icons.person_search), text: 'Lastnik'),
            ],
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _buildParcelForm(context)),
                _buildOwnerSearch(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _title(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _koHistory;
                }
                return _koHistory.where((String option) {
                  return option.contains(textEditingValue.text);
                });
              },
              onSelected: (String selection) {
                _koController.text = selection;
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController fieldController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                // Sync with our controller
                _koController.text = fieldController.text;
                fieldController.addListener(() {
                  _koController.text = fieldController.text;
                });

                return TextFormField(
                  controller: fieldController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'KO številka',
                    hintText: 'npr. 2361',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite KO številko';
                    }
                    return null;
                  },
                  enabled: !_isSearching,
                );
              },
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _parcelHistory;
                }
                return _parcelHistory.where((String option) {
                  return option.contains(textEditingValue.text);
                });
              },
              onSelected: (String selection) {
                _parcelController.text = selection;
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController fieldController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                // Sync with our controller
                _parcelController.text = fieldController.text;
                fieldController.addListener(() {
                  _parcelController.text = fieldController.text;
                });

                return TextFormField(
                  controller: fieldController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Parcela',
                    hintText: 'npr. 42 ali 1/1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grid_on),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite številko parcele';
                    }
                    return null;
                  },
                  enabled: !_isSearching,
                  onFieldSubmitted: (_) => _searchParcel(),
                );
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              _errorBox(_errorMessage!),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSearching ? null : () => Navigator.of(context).pop(),
                  child: const Text('Prekliči'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSearching ? null : _searchParcel,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isSearching ? 'Iskanje...' : 'Išči'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerSearch(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _onOwnerQueryChanged(),
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
                onChanged: (_) => _onOwnerQueryChanged(),
                decoration: const InputDecoration(
                  labelText: 'Naslov',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        if (_ownerError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _errorBox(_ownerError!),
          ),
        if (_ownerTruncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prikazanih prvih $_ownerLimit zadetkov — natančneje določi iskanje.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 16),
        Expanded(child: _buildOwnerResults(context)),
      ],
    );
  }

  Widget _buildOwnerResults(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasQuery = _nameController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty;
    if (!hasQuery) {
      return _hint(
        Icons.search,
        'Vnesi ime lastnika in/ali naslov za iskanje parcel.',
      );
    }
    if (_ownerHits.isEmpty) {
      return _hint(Icons.person_off, 'Ni zadetkov.');
    }
    return ListView.separated(
      itemCount: _ownerHits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final hit = _ownerHits[i];
        final locating = _locatingKey == _ownerKey(hit);
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
          trailing: locating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          onTap: _locatingKey != null ? null : () => _locateOwnerHit(hit),
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

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

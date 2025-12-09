import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/cadastral_service.dart';
import '../services/parcel_search_history_service.dart';

/// Bottom sheet for searching cadastral parcels by KO number and parcel number
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
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ParcelSearchDialog(
              mapController: mapController,
              onParcelFound: onParcelFound,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Iskanje parcele',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
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
                    Container(
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
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSearching
                            ? null
                            : () => Navigator.of(context).pop(),
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
            ),
          ),
        ],
      ),
    );
  }
}

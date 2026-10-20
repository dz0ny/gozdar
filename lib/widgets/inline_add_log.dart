import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/log_input_prefs_service.dart';
import '../utils/decimal_input.dart';

/// Always-visible quick-add bar at the bottom of the Hlodi tab: diameter,
/// length, then the round "+". Replaces the modal add sheet
/// so logging a pile of timber is a steady type → Dodaj → type loop without a
/// popup in between. Diameter and length are prefilled from the last added
/// log and kept after each add (focus back on the diameter with its text
/// selected), so a run of similar logs is just repeated "Dodaj". The species
/// is not chosen here; it comes from [species], picked via the total card.
class InlineAddLog extends StatefulWidget {
  final Future<void> Function(LogEntry entry) onAdd;
  final int? batchId;
  final String? species;

  const InlineAddLog({
    super.key,
    required this.onAdd,
    this.batchId,
    this.species,
  });

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
  bool _isSaving = false;
  int _addedCount = 0;

  final _inputPrefs = LogInputPrefsService();

  @override
  void initState() {
    super.initState();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
    _loadLastDimensions();
  }

  Future<void> _loadLastDimensions() async {
    final diameter = await _inputPrefs.getLastDiameter();
    final length = await _inputPrefs.getLastLength();
    if (!mounted) return;
    // Don't overwrite anything the user already started typing.
    if (diameter != null && _diameterController.text.isEmpty) {
      _diameterController.text = _formatDimension(diameter);
    }
    if (length != null && _lengthController.text.isEmpty) {
      _lengthController.text = _formatDimension(length);
    }
  }

  /// Shortest decimal form: 30 -> "30", 4.5 -> "4.5", 0.123 -> "0.12".
  String _formatDimension(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  /// Focus the diameter field with its text selected so typing replaces the
  /// retained value instead of appending to it.
  void _selectAllDiameter() {
    _diameterFocus.requestFocus();
    _diameterController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _diameterController.text.length,
    );
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

  LogEntry? _createEntry() {
    if (!_formKey.currentState!.validate() || _calculatedVolume == null) {
      return null;
    }
    return LogEntry(
      diameter: parseDecimal(_diameterController.text),
      length: parseDecimal(_lengthController.text),
      volume: _calculatedVolume!,
      species: widget.species,
      batchId: widget.batchId,
    );
  }

  Future<void> _saveAndContinue() async {
    final entry = _createEntry();
    if (entry == null) return;
    setState(() => _isSaving = true);
    try {
      await widget.onAdd(entry);
      if (entry.diameter != null && entry.length != null) {
        await _inputPrefs.saveLastDimensions(entry.diameter!, entry.length!);
      }
      if (!mounted) return;
      // Keep diameter/length (and the computed volume) for the next log.
      setState(() => _addedCount++);
      _selectAllDiameter();
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

  /// Big underlined number field, as on a pocket calculator: no label, the
  /// unit sits next to it as plain text.
  Widget _numberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputAction action,
    required void Function(String) onSubmitted,
    required TextStyle style,
    required Color underline,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: underline, width: 1.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.green[600]!, width: 2.5),
        ),
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      inputFormatters: [DecimalTextInputFormatter()],
      validator: (v) => v == null || v.isEmpty ? '' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canAdd = _calculatedVolume != null && !_isSaving;

    final numberStyle = textTheme.displaySmall!.copyWith(
      fontSize: 40,
      fontWeight: FontWeight.bold,
      color: cs.onSurface,
    );
    final unitStyle = textTheme.headlineSmall!.copyWith(
      fontSize: 26,
      color: cs.onSurfaceVariant,
    );
    final underline = cs.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: cs.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 39 cm  ×  8 m   (+)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _numberField(
                        controller: _diameterController,
                        focusNode: _diameterFocus,
                        action: TextInputAction.next,
                        onSubmitted: (_) => _lengthFocus.requestFocus(),
                        style: numberStyle,
                        underline: underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('cm', style: unitStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('×', style: unitStyle),
                    ),
                    Expanded(
                      flex: 4,
                      child: _numberField(
                        controller: _lengthController,
                        focusNode: _lengthFocus,
                        action: TextInputAction.done,
                        onSubmitted: (_) {
                          if (canAdd) _saveAndContinue();
                        },
                        style: numberStyle,
                        underline: underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('m', style: unitStyle),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: FilledButton(
                        onPressed: canAdd ? _saveAndContinue : null,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Tooltip(
                          message: 'Dodaj',
                          child: Icon(Icons.add, size: 44),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Volumen  =  0.955 m³      (Dodano: N on the left when > 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Volumen', style: unitStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('=', style: unitStyle),
                    ),
                    if (_addedCount > 0)
                      Text(
                        'Dodano: $_addedCount',
                        style: textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _calculatedVolume != null
                            ? _calculatedVolume!.toStringAsFixed(3)
                            : '–',
                        textAlign: TextAlign.right,
                        style: numberStyle.copyWith(
                          color: _calculatedVolume != null
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('m³', style: unitStyle),
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

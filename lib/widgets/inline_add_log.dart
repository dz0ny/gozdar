import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/log_entry.dart';
import '../services/log_input_prefs_service.dart';
import '../utils/decimal_input.dart';
import '../utils/formats.dart';

/// Always-visible quick-add bar at the bottom of the Hlodi tab: diameter,
/// length, then the round "+". Replaces the modal add sheet
/// so logging a pile of timber is a steady type → Dodaj → type loop without a
/// popup in between. The length is remembered (prefilled from the last added
/// log and kept after each add); the diameter is cleared after each add and
/// gets the focus, since it is what changes from log to log. The species is
/// not chosen here; it comes from [species], picked via the total card.
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
  // Plausible ranges; anything outside is almost surely a typo (354 cm).
  static const double _minDiameter = 1;
  static const double _maxDiameter = 200;
  static const double _minLength = 0.1;
  static const double _maxLength = 30;

  final _formKey = GlobalKey<FormState>();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _diameterFocus = FocusNode();
  final _lengthFocus = FocusNode();

  double? _calculatedVolume;
  bool _isSaving = false;
  int _addedCount = 0;
  bool _showAdded = false;
  Timer? _addedTimer;
  String? _rangeError;

  final _inputPrefs = LogInputPrefsService();

  @override
  void initState() {
    super.initState();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
    _loadLastDimensions();
  }

  Future<void> _loadLastDimensions() async {
    final length = await _inputPrefs.getLastLength();
    if (!mounted) return;
    // Don't overwrite anything the user already started typing.
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

  @override
  void dispose() {
    _addedTimer?.cancel();
    _diameterController.dispose();
    _lengthController.dispose();
    _diameterFocus.dispose();
    _lengthFocus.dispose();
    super.dispose();
  }

  void _updateVolume() {
    final diameter = parseDecimal(_diameterController.text);
    final length = parseDecimal(_lengthController.text);
    // Zero counts as "still typing" (e.g. "0.5"), not as out of range.
    final diameterBad = diameter != null &&
        diameter > 0 &&
        (diameter < _minDiameter || diameter > _maxDiameter);
    final lengthBad = length != null &&
        length > 0 &&
        (length < _minLength || length > _maxLength);
    setState(() {
      _rangeError = diameterBad
          ? context.l10n.logsInlineDiameterRange(
              Fmt.num(_minDiameter, 0), Fmt.num(_maxDiameter, 0))
          : lengthBad
              ? context.l10n.logsInlineLengthRange(
                  Fmt.num(_minLength, 1), Fmt.num(_maxLength, 0))
              : null;
      _calculatedVolume = (diameter != null &&
              length != null &&
              diameter > 0 &&
              length > 0 &&
              !diameterBad &&
              !lengthBad)
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
      // Keep the length for the next log; the diameter is what changes.
      setState(() {
        _addedCount++;
        _showAdded = true;
        _diameterController.clear();
      });
      // Brief confirmation in the label slot, then back to "Volumen".
      _addedTimer?.cancel();
      _addedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showAdded = false);
      });
      _diameterFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsSaveErrorWithDetail('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Big underlined number field, as on a pocket calculator: a small label
  /// above it, the unit sits next to it as plain text.
  Widget _numberField({
    required String label,
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
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
      // Tapping anywhere else (list, header, empty space) closes the keyboard.
      onTapOutside: (_) => focusNode.unfocus(),
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
                        label: context.l10n.logsInlineDiameterHint,
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
                        label: context.l10n.logsInlineLengthHint,
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
                    // Counts as part of the fields so tapping + keeps the
                    // keyboard open for the next log.
                    TextFieldTapRegion(
                      child: SizedBox(
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
                        child: Tooltip(
                          message: context.l10n.commonAdd,
                          child: Icon(Icons.add, size: 44),
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
                if (_rangeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _rangeError!,
                      style: textTheme.bodyMedium?.copyWith(color: cs.error),
                    ),
                  ),
                const SizedBox(height: 6),
                // Volumen  =  0,96 m³   (the label briefly reads "✓ Dodano: N"
                // after an add, in the same slot, so nothing shifts)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Not Flexible: a loose Flexible would reserve half the row
                    // and leave a gap after "m³".
                    Text(
                      _showAdded
                          ? '✓ ${context.l10n.logsInlineAdded(_addedCount)}'
                          : context.l10n.logsVolumeLabel,
                      style: _showAdded
                          ? unitStyle.copyWith(color: Colors.green[400])
                          : unitStyle,
                      maxLines: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('=', style: unitStyle),
                    ),
                    Expanded(
                      child: Text(
                        _calculatedVolume != null
                            ? Fmt.num(_calculatedVolume!, 2)
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

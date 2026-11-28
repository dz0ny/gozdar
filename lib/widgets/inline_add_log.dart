import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/log_entry.dart';
import '../services/log_input_prefs_service.dart';
import '../theme/motion.dart';
import '../utils/decimal_input.dart';
import '../utils/formats.dart';

/// Always-visible quick-add panel at the bottom of the Hlodi tab: diameter
/// and length tiles, then the volume and a wide "Dodaj" button. Replaces the modal add sheet
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
    final diameterBad =
        diameter != null &&
        diameter > 0 &&
        (diameter < _minDiameter || diameter > _maxDiameter);
    final lengthBad =
        length != null &&
        length > 0 &&
        (length < _minLength || length > _maxLength);
    setState(() {
      _rangeError = diameterBad
          ? context.l10n.logsInlineDiameterRange(
              Fmt.num(_minDiameter, 0),
              Fmt.num(_maxDiameter, 0),
            )
          : lengthBad
          ? context.l10n.logsInlineLengthRange(
              Fmt.num(_minLength, 1),
              Fmt.num(_maxLength, 0),
            )
          : null;
      _calculatedVolume =
          (diameter != null &&
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

  /// A rounded tile holding one number: a small label on top, the big
  /// number with its unit beside it. Tapping anywhere on the tile types into
  /// it; the outline turns green while it has the focus.
  Widget _numberTile({
    required String label,
    required String unit,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputAction action,
    required void Function(String) onSubmitted,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextFieldTapRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.requestFocus,
        child: ListenableBuilder(
          listenable: focusNode,
          builder: (context, child) => AnimatedContainer(
            duration: Motion.of(context, Motion.short),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: 2,
                color: focusNode.hasFocus
                    ? Colors.green[600]!
                    : Colors.transparent,
              ),
            ),
            child: child,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      style: textTheme.headlineLarge?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        errorStyle: TextStyle(height: 0, fontSize: 0),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: action,
                      onFieldSubmitted: onSubmitted,
                      // Tapping anywhere else closes the keyboard.
                      onTapOutside: (_) => focusNode.unfocus(),
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (v) => v == null || v.isEmpty ? '' : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: textTheme.titleLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canAdd = _calculatedVolume != null && !_isSaving;
    final volumeColor = _calculatedVolume != null
        ? Colors.green[400]
        : cs.onSurfaceVariant;

    // Part of the page, not a sheet: same background, a hairline above.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // [Premer 39 cm] [Dolžina 4 m]
                Row(
                  children: [
                    Expanded(
                      child: _numberTile(
                        label: context.l10n.logsInlineDiameterHint,
                        unit: 'cm',
                        controller: _diameterController,
                        focusNode: _diameterFocus,
                        action: TextInputAction.next,
                        onSubmitted: (_) => _lengthFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberTile(
                        label: context.l10n.logsInlineLengthHint,
                        unit: 'm',
                        controller: _lengthController,
                        focusNode: _lengthFocus,
                        action: TextInputAction.done,
                        onSubmitted: (_) {
                          if (canAdd) _saveAndContinue();
                        },
                      ),
                    ),
                  ],
                ),
                if (_rangeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _rangeError!,
                      style: textTheme.bodyMedium?.copyWith(color: cs.error),
                    ),
                  ),
                const SizedBox(height: 12),
                // Volumen                     0,96 m³
                // (the label briefly reads "✓ Dodano: N" after an add)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.short),
                      child: Text(
                        _showAdded
                            ? '✓ ${context.l10n.logsInlineAdded(_addedCount)}'
                            : context.l10n.logsVolumeLabel,
                        key: ValueKey(_showAdded),
                        maxLines: 1,
                        style: textTheme.titleMedium?.copyWith(
                          color: _showAdded
                              ? Colors.green[400]
                              : cs.onSurfaceVariant,
                          fontWeight: _showAdded ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _calculatedVolume != null
                            ? Fmt.num(_calculatedVolume!, 2)
                            : '–',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: volumeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'm³',
                      style: textTheme.titleLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Full width under the fields. Counts as part of the fields
                // so tapping it keeps the keyboard open for the next log.
                TextFieldTapRegion(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canAdd ? _saveAndContinue : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        textStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 24),
                      label: Text(context.l10n.commonAdd),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

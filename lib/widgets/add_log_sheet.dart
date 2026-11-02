import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
import '../models/log_entry.dart';
import '../utils/decimal_input.dart';
import '../utils/formats.dart';
import 'navigate_to_sheet.dart';
import 'sheet_parts.dart';

/// Short sheet for a log at a map point, opened from the long-press quick
/// view: diameter, length, the volume and Shrani. The length starts from
/// [lastLength] and the diameter gets the focus. Species, notes and a
/// manual volume stay in the full form for later edits.
class AddLogSheet extends StatefulWidget {
  // Same plausible ranges as the quick-add bar in the Hlodi tab.
  static const double minDiameter = 1;
  static const double maxDiameter = 200;
  static const double minLength = 0.1;
  static const double maxLength = 30;

  final LatLng position;
  final String? parcelLabel;
  final double? lastLength;
  final String? species;
  final VoidCallback onBack;

  const AddLogSheet({
    super.key,
    required this.position,
    required this.onBack,
    this.parcelLabel,
    this.lastLength,
    this.species,
  });

  /// Shows the sheet and returns the new log, or null when the user backs
  /// out or closes it. Back returns to the quick view through [onBack].
  static Future<LogEntry?> show({
    required BuildContext context,
    required LatLng position,
    String? parcelLabel,
    double? lastLength,
    String? species,
    VoidCallback? onBack,
  }) async {
    var backedOut = false;
    final log = await showModalBottomSheet<LogEntry>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddLogSheet(
        position: position,
        parcelLabel: parcelLabel,
        lastLength: lastLength,
        species: species,
        onBack: () {
          backedOut = true;
          Navigator.of(context).pop();
        },
      ),
    );
    if (backedOut) onBack?.call();
    return log;
  }

  @override
  State<AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<AddLogSheet> {
  final _diameter = TextEditingController();
  final _length = TextEditingController();

  @override
  void initState() {
    super.initState();
    final length = widget.lastLength;
    if (length != null) _length.text = _formatDimension(length);
  }

  @override
  void dispose() {
    _diameter.dispose();
    _length.dispose();
    super.dispose();
  }

  /// Shortest decimal form: 30 -> "30", 4.5 -> "4.5".
  static String _formatDimension(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  bool _diameterBad(double? d) =>
      d != null && d > 0 && (d < AddLogSheet.minDiameter || d > AddLogSheet.maxDiameter);

  bool _lengthBad(double? l) =>
      l != null && l > 0 && (l < AddLogSheet.minLength || l > AddLogSheet.maxLength);

  void _save(double diameter, double length, double volume) {
    Navigator.of(context).pop(LogEntry(
      diameter: diameter,
      length: length,
      volume: volume,
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      species: widget.species,
    ));
  }

  Widget _field(String label, String unit, TextEditingController controller,
      {bool autofocus = false,
      TextInputAction action = TextInputAction.next,
      VoidCallback? onSubmitted}) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: action,
      inputFormatters: [DecimalTextInputFormatter()],
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coords = NavigateToSheet.coordinates(widget.position);

    final diameter = parseDecimal(_diameter.text);
    final length = parseDecimal(_length.text);
    final error = _diameterBad(diameter)
        ? l10n.logsInlineDiameterRange(
            Fmt.num(AddLogSheet.minDiameter, 0), Fmt.num(AddLogSheet.maxDiameter, 0))
        : _lengthBad(length)
            ? l10n.logsInlineLengthRange(
                Fmt.num(AddLogSheet.minLength, 1), Fmt.num(AddLogSheet.maxLength, 0))
            : null;
    final volume = error == null &&
            diameter != null &&
            length != null &&
            diameter > 0 &&
            length > 0
        ? LogEntry.calculateVolume(diameter, length)
        : null;
    final onSave = volume == null ? null : () => _save(diameter!, length!, volume);

    return Padding(
      // Stay above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              SheetHeader(
                icon: Icons.forest,
                color: Colors.brown,
                title: l10n.mapwAddLogTitle,
                subtitle: widget.parcelLabel == null
                    ? coords
                    : '${widget.parcelLabel} · $coords',
                onBack: widget.onBack,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(l10n.logsInlineDiameterHint, 'cm', _diameter,
                        autofocus: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(l10n.logsInlineLengthHint, 'm', _length,
                        action: TextInputAction.done, onSubmitted: onSave),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (error != null)
                Text(error, style: textTheme.bodyMedium?.copyWith(color: cs.error))
              else
                Text(
                  volume == null ? '– m³' : '${Fmt.num(volume, 2)} m³',
                  textAlign: TextAlign.right,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: volume == null ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check),
                label: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../utils/decimal_input.dart';

/// Bottom sheet for configuring volume conversion factors (m³ → PRM/NM)
class ConversionSettingsSheet extends StatefulWidget {
  final double totalVolume;
  final double prmFactor;
  final double nmFactor;
  final void Function(double prm, double nm) onChanged;

  const ConversionSettingsSheet({
    super.key,
    required this.totalVolume,
    required this.prmFactor,
    required this.nmFactor,
    required this.onChanged,
  });

  @override
  State<ConversionSettingsSheet> createState() => _ConversionSettingsSheetState();
}

class _ConversionSettingsSheetState extends State<ConversionSettingsSheet> {
  late double _prm;
  late double _nm;
  late final TextEditingController _prmController;
  late final TextEditingController _nmController;

  @override
  void initState() {
    super.initState();
    _prm = widget.prmFactor;
    _nm = widget.nmFactor;
    _prmController = TextEditingController(text: _formatFactor(_prm));
    _nmController = TextEditingController(text: _formatFactor(_nm));
  }

  @override
  void dispose() {
    _prmController.dispose();
    _nmController.dispose();
    super.dispose();
  }

  String _formatFactor(double value) {
    var text = value.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    return text;
  }

  void _setPrm(double value) {
    setState(() => _prm = value);
    final text = _formatFactor(value);
    if (_prmController.text != text) {
      _prmController.text = text;
    }
  }

  void _setNm(double value) {
    setState(() => _nm = value);
    final text = _formatFactor(value);
    if (_nmController.text != text) {
      _nmController.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Text(
                  'Pretvorba volumna',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Current values display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.totalVolume.toStringAsFixed(2)} m³',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.totalVolume * _prm).toStringAsFixed(2)} PRM  •  ${(widget.totalVolume * _nm).toStringAsFixed(2)} NM',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PRM presets
            Text('PRM - Prostorninski meter drv', style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Zložena drva (polena). 1 PRM × faktor = m³ trdne mase.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FactorChip(label: 'Privzeto', value: 0.65, selected: _prm == 0.65, onTap: () => _setPrm(0.65)),
                _FactorChip(label: 'Bukev/Hrast', value: 0.67, selected: _prm == 0.67, onTap: () => _setPrm(0.67)),
                _FactorChip(label: 'Smreka/Jelka', value: 0.57, selected: _prm == 0.57, onTap: () => _setPrm(0.57)),
                _FactorChip(label: 'Mehki listavci', value: 0.60, selected: _prm == 0.60, onTap: () => _setPrm(0.60)),
              ],
            ),
            const SizedBox(height: 8),
            _CustomFactorField(
              controller: _prmController,
              onChanged: (value) => setState(() => _prm = value),
            ),
            const SizedBox(height: 12),

            // NM presets
            Text('NM - Nasuti meter', style: Theme.of(context).textTheme.titleSmall),
            Text(
              'Nasut les (sekanci, odpadki). 1 NM × faktor = m³ trdne mase.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FactorChip(label: 'Privzeto', value: 0.40, selected: _nm == 0.40, onTap: () => _setNm(0.40)),
                _FactorChip(label: 'Trdi les', value: 0.45, selected: _nm == 0.45, onTap: () => _setNm(0.45)),
                _FactorChip(label: 'Mehki les', value: 0.35, selected: _nm == 0.35, onTap: () => _setNm(0.35)),
              ],
            ),
            const SizedBox(height: 8),
            _CustomFactorField(
              controller: _nmController,
              onChanged: (value) => setState(() => _nm = value),
            ),
            const SizedBox(height: 16),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onChanged(_prm, _nm);
                  Navigator.pop(context);
                },
                child: const Text('Potrdi'),
              ),
            ),
          ],
        ),
      );
  }
}

/// Selectable chip for conversion factor presets
class _FactorChip extends StatelessWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const _FactorChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label ($value)',
          style: TextStyle(
            fontSize: 12,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Compact custom-value input for a conversion factor
class _CustomFactorField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(double value) onChanged;

  const _CustomFactorField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalTextInputFormatter()],
        decoration: const InputDecoration(
          labelText: 'Faktor po meri',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (text) {
          final value = parseDecimal(text);
          if (value != null && value > 0) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

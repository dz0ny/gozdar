import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _prm = widget.prmFactor;
    _nm = widget.nmFactor;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
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
                _FactorChip(label: 'Bukev/Hrast', value: 0.67, selected: _prm == 0.67, onTap: () => setState(() => _prm = 0.67)),
                _FactorChip(label: 'Smreka/Jelka', value: 0.57, selected: _prm == 0.57, onTap: () => setState(() => _prm = 0.57)),
                _FactorChip(label: 'Mehki listavci', value: 0.60, selected: _prm == 0.60, onTap: () => setState(() => _prm = 0.60)),
              ],
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
                _FactorChip(label: 'Trdi les', value: 0.45, selected: _nm == 0.45, onTap: () => setState(() => _nm = 0.45)),
                _FactorChip(label: 'Mehki les', value: 0.35, selected: _nm == 0.35, onTap: () => setState(() => _nm = 0.35)),
                _FactorChip(label: 'Povprečje', value: 0.40, selected: _nm == 0.40, onTap: () => setState(() => _nm = 0.40)),
              ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label ($value)',
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

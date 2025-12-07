import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';

class WorkerSettingsDialog extends StatefulWidget {
  final VoidCallback? onOpenDownload;

  const WorkerSettingsDialog({super.key, this.onOpenDownload});

  @override
  State<WorkerSettingsDialog> createState() => _WorkerSettingsDialogState();
}

class _WorkerSettingsDialogState extends State<WorkerSettingsDialog> {
  final _urlController = TextEditingController();
  int _debugTapCount = 0;
  bool _showProxySettings = false;

  @override
  void initState() {
    super.initState();
    final workerUrl = context.read<MapProvider>().workerUrl;
    if (workerUrl != null) {
      _urlController.text = workerUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onDebugTap() {
    setState(() {
      _debugTapCount++;
      if (_debugTapCount >= 3) {
        _showProxySettings = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pospeševalnik odklenjen'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _save() {
    final url = _urlController.text.trim();
    // Validate simple URL format
    if (url.isNotEmpty && !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL se mora začeti s http:// ali https://'),
        ),
      );
      return;
    }

    // Remove trailing slash if present
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    context.read<MapProvider>().setWorkerUrl(
      cleanUrl.isEmpty ? null : cleanUrl,
    );
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleanUrl.isEmpty
              ? 'Cloudflare proxy onemogočen'
              : 'Cloudflare proxy nastavljen',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes (debug info toggle)
    final mapProvider = context.watch<MapProvider>();

    return AlertDialog(
      title: const Text('Nastavitve karte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Proxy settings - hidden until unlocked
            if (_showProxySettings) ...[
              Text(
                'Pospeševalnik (Proxy)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vnesite URL Cloudflare Worker-ja za hitrejše nalaganje zemljevidov.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Worker URL',
                  hintText: 'https://moj-projekt.workers.dev',
                  border: OutlineInputBorder(),
                  helperText: 'Pustite prazno za onemogočanje',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
            ],
            Text(
              'Prenos kart (Offline)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prenesite karte za uporabo brez internetne povezave.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // Close settings dialog
                  widget.onOpenDownload?.call(); // Open download dialog
                },
                icon: const Icon(Icons.download_for_offline),
                label: const Text('Odpri orodje za prenos'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showProxySettings ? null : _onDebugTap,
              child: const Text(
                'Razhroščevanje',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Pokaži podatke o karti'),
              subtitle: const Text('Zoom, koordinate, rotacija'),
              value: mapProvider.isDebugInfoVisible,
              onChanged: (value) {
                mapProvider.setDebugInfoVisible(value);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Prekliči'),
        ),
        FilledButton(onPressed: _save, child: const Text('Shrani')),
      ],
    );
  }
}

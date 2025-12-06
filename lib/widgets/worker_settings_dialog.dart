import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';

class WorkerSettingsDialog extends StatefulWidget {
  const WorkerSettingsDialog({super.key});

  @override
  State<WorkerSettingsDialog> createState() => _WorkerSettingsDialogState();
}

class _WorkerSettingsDialogState extends State<WorkerSettingsDialog> {
  final _urlController = TextEditingController();

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
    return AlertDialog(
      title: const Text('Nastavitve pospeševalnika (Worker)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vnesite URL Cloudflare Worker-ja za hitrejše nalaganje zemljevidov in podporo za caching.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
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
        ],
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

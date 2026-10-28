import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Progress of one file download: what is downloading, a thick progress bar,
/// size, speed and time left, plus a cancel button.
class DownloadProgressView extends StatefulWidget {
  /// Small label above, e.g. "Prenašam regijo…".
  final String title;

  /// What is downloading, e.g. the region name; shown prominently.
  final String? name;

  final int received;
  final int? total;
  final VoidCallback onCancel;

  const DownloadProgressView({
    super.key,
    required this.title,
    this.name,
    required this.received,
    required this.total,
    required this.onCancel,
  });

  @override
  State<DownloadProgressView> createState() => _DownloadProgressViewState();
}

class _DownloadProgressViewState extends State<DownloadProgressView> {
  final _clock = Stopwatch()..start();
  int _startBytes = 0;

  @override
  void didUpdateWidget(DownloadProgressView old) {
    super.didUpdateWidget(old);
    // A new file started (multi-region downloads): measure speed afresh.
    if (widget.received < old.received || widget.name != old.name) {
      _clock.reset();
      _startBytes = widget.received;
    }
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

  /// "3.2 MB/s • ~2 min", or null until there is enough to estimate from.
  String? _rate() {
    final secs = _clock.elapsedMilliseconds / 1000;
    final done = widget.received - _startBytes;
    if (secs < 2 || done <= 0) return null;
    final perSec = done / secs;
    final speed = '${(perSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    final total = widget.total;
    if (total == null || total <= widget.received) return speed;
    final left = ((total - widget.received) / perSec).round();
    final eta = left >= 60 ? '~${(left / 60).ceil()} min' : '~$left s';
    return '$speed • $eta';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = widget.total;
    final pct = (total != null && total > 0)
        ? (widget.received / total).clamp(0.0, 1.0)
        : null;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final rate = _rate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 20,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: muted),
                  if (widget.name != null)
                    Text(
                      widget.name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (pct != null)
              Text(
                '${(pct * 100).toStringAsFixed(0)} %',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            IconButton(
              tooltip: context.l10n.commonCancel,
              icon: const Icon(Icons.close),
              onPressed: widget.onCancel,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 8),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              total != null
                  ? '${_mb(widget.received)} / ${_mb(total)} MB'
                  : '${_mb(widget.received)} MB',
              style: muted,
            ),
            const Spacer(),
            if (rate != null) Text(rate, style: muted),
          ],
        ),
      ],
    );
  }
}

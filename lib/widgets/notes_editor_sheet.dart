import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// Bottom sheet for editing notes
class NotesEditorSheet extends StatefulWidget {
  final String? initialNotes;
  final String? title;

  const NotesEditorSheet({
    super.key,
    this.initialNotes,
    this.title,
  });

  @override
  State<NotesEditorSheet> createState() => _NotesEditorSheetState();
}

class _NotesEditorSheetState extends State<NotesEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _changed => _controller.text != (widget.initialNotes ?? '');

  void _save() {
    Navigator.of(context).pop(_controller.text);
  }

  /// ✕ / back: close right away when nothing changed, else ask first so
  /// typed notes aren't lost by accident.
  Future<void> _close() async {
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.notesDiscardTitle),
        content: Text(context.l10n.notesDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.notesKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.notesDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Lift the sheet above the keyboard and let it scroll when space is
    // short, so Shrani stays reachable. (The caller opens the sheet with
    // isScrollControlled: true.)
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      widget.title ?? context.l10n.logsNotesLabel,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: context.l10n.commonClose,
                      onPressed: _close,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: context.l10n.logsNotesLabel,
                    hintText: context.l10n.logsNotesEditorHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 10,
                  minLines: 5,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  // Rebuild so PopScope sees whether there are edits.
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(context.l10n.commonSave),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
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

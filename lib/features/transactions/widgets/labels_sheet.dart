import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/widgets/glass_sheet.dart';

/// Lets the user pick labels for a transaction: type a new one or tap one
/// used before. Returns the new list, or null when dismissed.
Future<List<String>?> showLabelsSheet(
  BuildContext context, {
  required List<String> selected,
  required List<String> suggestions,
}) {
  return showAppSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _LabelsSheet(selected: selected, suggestions: suggestions),
  );
}

class _LabelsSheet extends StatefulWidget {
  const _LabelsSheet({required this.selected, required this.suggestions});

  final List<String> selected;
  final List<String> suggestions;

  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  late List<String> _selected = List.of(widget.selected);
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _has(String label) =>
      _selected.any((l) => l.toLowerCase() == label.toLowerCase());

  void _toggle(String label) {
    setState(() {
      if (_has(label)) {
        _selected.removeWhere((l) => l.toLowerCase() == label.toLowerCase());
      } else {
        _selected = Transaction.normalizeLabels([..._selected, label]);
      }
    });
  }

  void _addTyped() {
    final typed = Transaction.normalizeLabels([_controller.text]);
    if (typed.isEmpty) return;
    setState(() {
      _selected = Transaction.normalizeLabels([..._selected, ...typed]);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final others = widget.suggestions.where((s) => !_has(s)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.xl,
        0,
        Space.xl,
        MediaQuery.viewInsetsOf(context).bottom + Space.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Labels', style: text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            'Group spending across categories, like a trip or an event.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _controller,
            autofocus: widget.suggestions.isEmpty,
            maxLength: Transaction.maxLabelLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTyped(),
            decoration: InputDecoration(
              labelText: 'New label',
              hintText: 'e.g. Goa trip',
              prefixIcon: const Icon(Icons.sell_outlined),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Add label',
                icon: const Icon(Icons.add),
                onPressed: _addTyped,
              ),
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final label in _selected)
                  InputChip(
                    label: Text(label),
                    selected: true,
                    onDeleted: () => _toggle(label),
                    deleteButtonTooltipMessage: 'Remove $label',
                    onPressed: () => _toggle(label),
                  ),
              ],
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Text(
              'Used before',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final label in others)
                      FilterChip(
                        label: Text(label),
                        selected: false,
                        onSelected: (_) => _toggle(label),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: () {
              // Text still in the box counts, so it is not lost.
              _addTyped();
              Navigator.pop(context, _selected);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

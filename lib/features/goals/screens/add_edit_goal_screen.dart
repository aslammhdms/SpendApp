import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/goal.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_dialog.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/goals_provider.dart';

class AddEditGoalScreen extends ConsumerStatefulWidget {
  const AddEditGoalScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends ConsumerState<AddEditGoalScreen> {
  static const icons = [
    '💰', '📱', '💻', '🚗', '🏠', '✈️', '🎓', '🎁', '🛡️', '🎮', '📷', '🚴',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  DateTime? _targetDate;
  String _icon = icons.first;
  int? _color;
  Goal? _existing;
  bool _isLoading = false;

  bool get isEditing => widget.goalId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final goal = await ref.read(goalRepositoryProvider).getById(widget.goalId!);
    if (!mounted) return;
    setState(() {
      _existing = goal;
      if (goal != null) {
        _name.text = goal.name;
        _target.text = _plain(goal.targetAmount);
        _saved.text = goal.savedAmount > 0 ? _plain(goal.savedAmount) : '';
        _targetDate = goal.targetDate;
        _icon = goal.icon;
        _color = goal.color;
      }
      _isLoading = false;
    });
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double? _parse(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', ''));
    return v != null && v.isFinite ? v : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: 'Reach it by',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = _parse(_target.text)!;
    final saved = _parse(_saved.text) ?? 0;
    final color = _color ?? context.palette.chart.first.toARGB32();
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      final existing = _existing;
      if (existing != null) {
        await repo.update(existing.copyWith(
          name: _name.text,
          targetAmount: target,
          savedAmount: saved,
          targetDate: _targetDate,
          icon: _icon,
          color: color,
        ));
      } else {
        await repo.create(
          name: _name.text,
          targetAmount: target,
          savedAmount: saved,
          targetDate: _targetDate,
          icon: _icon,
          color: color,
        );
      }
      ref.invalidate(goalsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Delete goal'),
        content: const Text('Delete this goal? Your transactions are not '
            'affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(goalRepositoryProvider).delete(widget.goalId!);
              ref.invalidate(goalsProvider);
              if (mounted) context.pop();
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).currency;
    final symbol = CurrencyUtils.getCurrency(currency).symbol;
    final colors = context.palette.chart;
    final selectedColor = _color ?? colors.first.toARGB32();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    String? amountCheck(String? value, {required bool required}) {
      if (value == null || value.trim().isEmpty) {
        return required ? 'Enter an amount' : null;
      }
      final v = _parse(value);
      if (v == null || v < 0 || (required && v == 0)) {
        return 'Enter a valid amount';
      }
      return null;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(isEditing ? 'Edit goal' : 'New goal'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete goal',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isLoading && isEditing && _existing == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: ScreenInsets.of(context, top: Space.lg),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'What are you saving for?',
                      hintText: 'e.g. New phone',
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a name'
                        : null,
                  ),
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    controller: _target,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Target amount',
                      prefixText: '$symbol ',
                    ),
                    validator: (v) => amountCheck(v, required: true),
                  ),
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    controller: _saved,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Saved so far (optional)',
                      prefixText: '$symbol ',
                    ),
                    validator: (v) => amountCheck(v, required: false),
                  ),
                  const SizedBox(height: Space.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Reach it by (optional)'),
                    subtitle: Text(_targetDate == null
                        ? 'No date'
                        : AppDateUtils.formatDisplayDate(_targetDate!)),
                    trailing: _targetDate == null
                        ? null
                        : IconButton(
                            tooltip: 'Remove date',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _targetDate = null),
                          ),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: Space.md),
                  Text('Icon', style: text.titleSmall),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final icon in icons)
                        _Pick(
                          selected: icon == _icon,
                          semanticLabel: 'Icon $icon',
                          onTap: () => setState(() => _icon = icon),
                          child: CategoryIcon(
                            emoji: icon,
                            color: Color(selectedColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Text('Colour', style: text.titleSmall),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (var i = 0; i < colors.length; i++)
                        _Pick(
                          selected: colors[i].toARGB32() == selectedColor,
                          semanticLabel: 'Colour ${i + 1}',
                          onTap: () =>
                              setState(() => _color = colors[i].toARGB32()),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors[i],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: Text(isEditing ? 'Update' : 'Create goal'),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Money you put towards a goal is not counted as spending.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

/// A selectable round choice with a ring when chosen.
class _Pick extends StatelessWidget {
  const _Pick({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: Sizes.touchTarget + 4,
          height: Sizes.touchTarget + 4,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

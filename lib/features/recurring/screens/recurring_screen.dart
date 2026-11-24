import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/category.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/add_edit_transaction_screen.dart'
    show repeatLabel;
import '../providers/recurring_provider.dart';
import '../../../shared/widgets/app_loader.dart';

/// Rent, subscriptions, salary: payments SpendSheet adds by itself.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRulesProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Repeating payments')),
      body: rulesAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return EmptyState(
              icon: Icons.repeat_rounded,
              title: 'No repeating payments',
              subtitle: 'Add an expense or income and set Repeat, such as '
                  'rent every month. SpendSheet adds it again on each date.',
              action: FilledButton.icon(
                onPressed: () => context.push('/transactions/add'),
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'),
              ),
            );
          }
          return RefreshIndicator(
            edgeOffset: ScreenInsets.topOf(context),
            onRefresh: () => ref.refresh(recurringRulesProvider.future),
            child: ListView.separated(
              padding: ScreenInsets.of(context, bottom: Space.fabClearance),
              itemCount: rules.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xs, 0, Space.xs, Space.xs),
                    child: Text(
                      'Each one is added when its date comes and you open '
                      'SpendSheet. You get a reminder the day before.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                final rule = rules[index - 1];
                return _RuleCard(
                  rule: rule,
                  category: _find(categories, rule.categoryId),
                  currency: currency,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (rulesAsync.valueOrNull?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/transactions/add'),
              tooltip: 'Add transaction',
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  static Category? _find(List<Category> categories, String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({
    required this.rule,
    required this.category,
    required this.currency,
  });

  final RecurringRule rule;
  final Category? category;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isIncome = rule.type == TransactionType.income;
    final when = rule.isActive
        ? '${repeatLabel(rule.frequency)} · next ${shortDate(rule.nextDueDate)}'
        : 'Paused';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showRepeatEditor(context, ref, rule),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, 0, Space.md),
          child: Row(
            children: [
              CategoryIcon(
                emoji: category?.icon ?? '🔁',
                color: Color(category?.color ?? scheme.primary.toARGB32()),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name,
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              MoneyText(
                rule.amount,
                currency: currency,
                kind: isIncome ? MoneyKind.income : MoneyKind.expense,
                prefix: isIncome ? '+' : '−',
                style: text.titleSmall,
              ),
              PopupMenuButton<String>(
                tooltip: 'More for ${rule.name}',
                onSelected: (action) async {
                  final repo = ref.read(recurringRepositoryProvider);
                  switch (action) {
                    case 'pause':
                      await repo.setActive(rule, !rule.isActive);
                    case 'delete':
                      if (!await _confirmDelete(context)) return;
                      await repo.delete(rule.id);
                  }
                  ref.invalidate(recurringRulesProvider);
                  // Reminders follow the rules.
                  ref.read(dashboardProvider.notifier).refresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(rule.isActive ? 'Pause' : 'Resume'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Delete repeating payment'),
        content: Text('SpendSheet stops adding "${rule.name}". Payments it '
            'already added stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// "30 Nov", with the year only when it is not this year.
String shortDate(DateTime date) {
  final sameYear = date.year == DateTime.now().year;
  return DateFormat(sameYear ? 'd MMM' : 'd MMM y').format(date);
}

/// Edits a repeating payment's name, amount, how often and next date.
Future<void> showRepeatEditor(
  BuildContext context,
  WidgetRef ref,
  RecurringRule rule,
) async {
  final saved = await showAppSheet<RecurringRule>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RepeatEditor(rule: rule),
  );
  if (saved == null) return;
  await ref.read(recurringRepositoryProvider).update(saved);
  ref.invalidate(recurringRulesProvider);
  ref.read(dashboardProvider.notifier).refresh();
}

class _RepeatEditor extends StatefulWidget {
  const _RepeatEditor({required this.rule});

  final RecurringRule rule;

  @override
  State<_RepeatEditor> createState() => _RepeatEditorState();
}

class _RepeatEditorState extends State<_RepeatEditor> {
  late final _name = TextEditingController(text: widget.rule.name);
  late final _amount =
      TextEditingController(text: _plain(widget.rule.amount));
  late RecurringFrequency _frequency = widget.rule.frequency;
  late DateTime _next = widget.rule.nextDueDate;
  late DateTime? _end = widget.rule.endDate;
  String? _error;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickNext() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _next,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Next payment',
    );
    if (picked != null) {
      setState(() => _next = DateTime(
          picked.year, picked.month, picked.day, _next.hour, _next.minute));
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _next,
      firstDate: _next,
      lastDate: DateTime(_next.year + 30),
      helpText: 'Last payment on or before',
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    final end = _end;
    Navigator.pop(
      context,
      RecurringRule(
        id: widget.rule.id,
        name: name,
        amount: amount,
        type: widget.rule.type,
        categoryId: widget.rule.categoryId,
        accountId: widget.rule.accountId,
        frequency: _frequency,
        interval: widget.rule.interval,
        nextDueDate: _next,
        endDate: end != null && end.isBefore(_next) ? null : end,
        note: widget.rule.note,
        isActive: widget.rule.isActive,
        createdAt: widget.rule.createdAt,
        updatedAt: widget.rule.updatedAt,
        deletedAt: widget.rule.deletedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.xl,
        0,
        Space.xl,
        MediaQuery.viewInsetsOf(context).bottom + Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Repeating payment', style: text.titleMedium),
            const SizedBox(height: Space.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<RecurringFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Repeats'),
              items: [
                for (final f in RecurringFrequency.values)
                  DropdownMenuItem(value: f, child: Text(repeatLabel(f))),
              ],
              onChanged: (f) => setState(() => _frequency = f ?? _frequency),
            ),
            const SizedBox(height: Space.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Next payment'),
              subtitle: Text(AppDateUtils.formatDisplayDate(_next)),
              onTap: _pickNext,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Ends'),
              subtitle: Text(_end == null
                  ? 'Never'
                  : AppDateUtils.formatDisplayDate(_end!)),
              trailing: _end == null
                  ? null
                  : IconButton(
                      tooltip: 'Never ends',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _end = null),
                    ),
              onTap: _pickEnd,
            ),
            if (_error != null) ...[
              Text(_error!,
                  style: text.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: Space.sm),
            ],
            const SizedBox(height: Space.sm),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

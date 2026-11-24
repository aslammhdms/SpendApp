import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/goal.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Savings goals')),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load goals: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              icon: Icons.savings_outlined,
              title: 'No savings goals yet',
              subtitle: 'Save towards something, like a new phone or a '
                  'trip, and see how close you are.',
              action: FilledButton.icon(
                onPressed: () => context.push('/goals/add'),
                icon: const Icon(Icons.add),
                label: const Text('New goal'),
              ),
            );
          }
          return RefreshIndicator(
            edgeOffset: ScreenInsets.topOf(context),
            onRefresh: () => ref.refresh(goalsProvider.future),
            child: ListView.separated(
              padding: ScreenInsets.of(context, bottom: Space.fabClearance),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: Space.md),
              itemBuilder: (context, index) {
                final goal = goals[index];
                return GoalCard(
                  goal: goal,
                  currency: currency,
                  onTap: () => showGoalActions(context, ref, goal),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (goalsAsync.valueOrNull?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/goals/add'),
              tooltip: 'New goal',
              icon: const Icon(Icons.add),
              label: const Text('New goal'),
            )
          : null,
    );
  }
}

/// Add money, take money out, edit.
Future<void> showGoalActions(
  BuildContext context,
  WidgetRef ref,
  Goal goal,
) async {
  final action = await showAppSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
            child: Text(goal.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add money'),
            onTap: () => Navigator.pop(context, 'add'),
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Take money out'),
            enabled: goal.savedAmount > 0,
            onTap: () => Navigator.pop(context, 'take'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit goal'),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'edit') {
    context.push('/goals/edit/${Uri.encodeComponent(goal.id)}');
    return;
  }
  final adding = action == 'add';
  final currency = ref.read(settingsProvider).currency;
  final amount = await _askAmount(context,
      title: adding ? 'Add to ${goal.name}' : 'Take out of ${goal.name}',
      currency: currency,
      max: adding ? null : goal.savedAmount);
  if (amount == null) return;
  await ref
      .read(goalRepositoryProvider)
      .addToSaved(goal, adding ? amount : -amount);
  ref.invalidate(goalsProvider);
  if (context.mounted && adding && goal.savedAmount + amount >= goal.targetAmount &&
      !goal.isReached) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You reached ${goal.name}. Well done!')),
    );
  }
}

Future<double?> _askAmount(
  BuildContext context, {
  required String title,
  required String currency,
  double? max,
}) {
  return showAppSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AmountSheet(title: title, currency: currency, max: max),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.title, required this.currency, this.max});

  final String title;
  final String currency;
  final double? max;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', ''));
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    final max = widget.max;
    if (max != null && value > max) {
      setState(() => _error = 'Only '
          '${CurrencyUtils.format(max, currencyCode: widget.currency)} is saved');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyUtils.getCurrency(widget.currency).symbol;
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
          Text(widget.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: Space.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onSubmitted: (_) => _done(),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '$symbol ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(onPressed: _done, child: const Text('Save')),
        ],
      ),
    );
  }
}

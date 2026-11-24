import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../data/models/budget.dart';
import '../../../core/services/notification_service.dart';
import '../providers/budgets_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/glass_dialog.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/screen_insets.dart';

class AddEditBudgetScreen extends ConsumerStatefulWidget {
  final String? budgetId;

  const AddEditBudgetScreen({
    super.key,
    this.budgetId,
  });

  @override
  ConsumerState<AddEditBudgetScreen> createState() =>
      _AddEditBudgetScreenState();
}

class _AddEditBudgetScreenState extends ConsumerState<AddEditBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  BudgetPeriod _period = BudgetPeriod.monthly;
  String? _categoryId;
  bool _isLoading = false;
  Budget? _existingBudget;

  bool get isEditing => widget.budgetId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadBudget();
    }
  }

  Future<void> _loadBudget() async {
    setState(() => _isLoading = true);
    final repository = ref.read(budgetRepositoryProvider);
    final budget = await repository.getById(widget.budgetId!);

    if (budget != null && mounted) {
      setState(() {
        _existingBudget = budget;
        _nameController.text = budget.name;
        _amountController.text = budget.amount.toString();
        _period = budget.period;
        _categoryId = budget.categoryId;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Budget alerts need notification permission on Android 13 and later,
  /// so ask for it when a budget is created.
  Future<void> _requestAlertPermission() async {
    final settings = ref.read(settingsProvider);
    if (settings.notificationsEnabled && settings.budgetAlertsEnabled) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(budgetsProvider.notifier);

      if (isEditing && _existingBudget != null) {
        await notifier.updateBudget(
          _existingBudget!.copyWith(
            name: _nameController.text.trim(),
            amount: amount,
            period: _period,
            categoryId: _categoryId,
          ),
        );
      } else {
        await notifier.createBudget(
          name: _nameController.text.trim(),
          amount: amount,
          period: _period,
          categoryId: _categoryId,
        );
        await _requestAlertPermission();
      }

      if (mounted) {
        await ref.read(budgetsProvider.notifier).loadBudgets();
        await ref.read(dashboardProvider.notifier).refresh();
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(isEditing ? 'Edit Budget' : 'New Budget'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete budget',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isLoading && isEditing
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: ScreenInsets.of(context, top: Space.lg),
                children: [
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Budget Name',
                      hintText: 'e.g., Monthly Groceries',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Budget Amount',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Period Selection
                  Text(
                    'Period',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: BudgetPeriod.values.map((period) {
                      final isSelected = _period == period;
                      return ChoiceChip(
                        label: Text(_getPeriodLabel(period)),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _period = period);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Category Selection
                  Text(
                    'Category (Optional)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leave empty for an overall budget',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          avatar: const Icon(Icons.all_inclusive, size: 18),
                          label: const Text('Overall'),
                          selected: _categoryId == null,
                          onSelected: (_) {
                            setState(() => _categoryId = null);
                          },
                        ),
                        ...categories.map((category) {
                          final isSelected = category.id == _categoryId;
                          final icon = iconForEmoji(category.icon);
                          return FilterChip(
                            avatar: icon != null
                                ? Icon(icon, size: 18)
                                : Text(category.icon),
                            label: Text(category.name),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _categoryId = category.id);
                            },
                          );
                        }),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Failed to load categories'),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveBudget,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update' : 'Create Budget'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getPeriodLabel(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(budgetsProvider.notifier)
                  .deleteBudget(widget.budgetId!);
              if (mounted) {
                context.pop();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

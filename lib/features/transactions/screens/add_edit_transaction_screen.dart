import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../../../data/models/loan.dart';
import '../../../data/models/person.dart';
import '../providers/transactions_provider.dart';
import '../widgets/amount_input_pad.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/money_text.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../loans/providers/loans_provider.dart';

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddEditTransactionScreen({
    super.key,
    this.transactionId,
  });

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransactionType _type = TransactionType.expense;
  double _amount = 0;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _date = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  Transaction? _existingTransaction;

  // Loan tab state
  String? _selectedPersonId;
  LoanType _loanType = LoanType.lent;
  bool _isCreatingNewPerson = false;
  final TextEditingController _newPersonController = TextEditingController();
  List<Person> _people = [];
  bool _isLoanTab = false;

  bool get isEditing => widget.transactionId != null;
  int get _tabCount => isEditing ? 3 : 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);

    if (isEditing) {
      _loadTransaction();
    } else {
      _loadPeople();
    }
  }

  Future<void> _loadTransaction() async {
    setState(() => _isLoading = true);
    final repository = ref.read(transactionRepositoryProvider);
    final transaction = await repository.getById(widget.transactionId!);

    if (transaction != null && mounted) {
      setState(() {
        _existingTransaction = transaction;
        _amount = transaction.amount;
        _type = transaction.type;
        _categoryId = transaction.categoryId;
        _accountId = transaction.accountId;
        _toAccountId = transaction.toAccountId;
        _date = transaction.date;
        _noteController.text = transaction.note ?? '';
        _tabController.index = _type.index;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPeople() async {
    final repo = ref.read(personRepositoryProvider);
    final people = await repo.getAll();
    if (mounted) {
      setState(() => _people = people);
    }
  }

  void _onTabChanged() {
    setState(() {
      if (!isEditing && _tabController.index == 3) {
        _isLoanTab = true;
      } else {
        _isLoanTab = false;
        _type = TransactionType.values[_tabController.index];
      }
      _categoryId = null; // Reset category when type changes
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _newPersonController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    // Loan tab validation
    if (_isLoanTab) {
      if (_selectedPersonId == null && !_isCreatingNewPerson) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or create a person')),
        );
        return;
      }
      if (_isCreatingNewPerson && _newPersonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a person name')),
        );
        return;
      }
    } else {
      if (_categoryId == null && _type != TransactionType.transfer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      if (_accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account')),
        );
        return;
      }

      if (_type == TransactionType.transfer && _toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select destination account')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoanTab) {
        // Save as loan
        final notifier = ref.read(loansProvider.notifier);
        String personId;

        if (_isCreatingNewPerson) {
          final person = await notifier.createPerson(
            name: _newPersonController.text.trim(),
          );
          personId = person.id;
        } else {
          personId = _selectedPersonId!;
        }

        await notifier.createLoan(
          personId: personId,
          type: _loanType,
          amount: _amount,
          date: _date,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

        HapticFeedback.mediumImpact();
        if (mounted) {
          await ref.read(dashboardProvider.notifier).refresh();
          if (mounted) context.pop();
        }
      } else {
        // Save as transaction
        final repository = ref.read(transactionRepositoryProvider);

        if (isEditing && _existingTransaction != null) {
          await repository.update(
            _existingTransaction!.copyWith(
              amount: _amount,
              type: _type,
              categoryId: _categoryId ?? '',
              accountId: _accountId!,
              toAccountId: _toAccountId,
              date: _date,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          );
        } else {
          await repository.create(
            amount: _amount,
            type: _type,
            categoryId: _categoryId ?? '',
            accountId: _accountId!,
            toAccountId: _toAccountId,
            date: _date,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
        }

        HapticFeedback.mediumImpact();
        if (mounted) {
          await ref.read(dashboardProvider.notifier).refresh();
          await ref
              .read(transactionsProvider.notifier)
              .loadTransactions(refresh: true);
          if (mounted) context.pop();
        }
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
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);
    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final currency = ref.watch(settingsProvider).currency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (typeContainer, onTypeContainer) = _typeColors();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete transaction',
              onPressed: _confirmDelete,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              0,
              Space.lg,
              Space.sm + 2,
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(Space.xs),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: Radii.mdAll,
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Expense'),
                  const Tab(text: 'Income'),
                  const Tab(text: 'Transfer'),
                  if (!isEditing) const Tab(text: 'Loan'),
                ],
                indicator: BoxDecoration(
                  color: typeContainer,
                  borderRadius: Radii.smAll,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: onTypeContainer,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: text.labelLarge,
                unselectedLabelStyle: text.labelLarge,
                splashBorderRadius: Radii.smAll,
                labelPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AmountInputPad(
              initialAmount: _amount,
              currency: currency,
              onAmountChanged: (amount) {
                setState(() => _amount = amount);
              },
              middle: _isLoanTab
                  ? _buildLoanForm()
                  : _buildTransactionFields(
                      _type == TransactionType.expense
                          ? expenseCategoriesAsync
                          : incomeCategoriesAsync,
                      accountsAsync,
                      currency,
                    ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.lg,
          ),
          child: FilledButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(Sizes.touchTarget + 4),
            ),
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionFields(
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Account>> accountsAsync,
    String currency,
  ) {
    final isTransfer = _type == TransactionType.transfer;
    final accounts = accountsAsync.valueOrNull ?? const <Account>[];
    String accountName(String? id) {
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      return accountsAsync.isLoading ? '…' : 'Choose';
    }

    final accountTile = _DetailTile(
      caption: isTransfer ? 'From Account' : 'Account',
      value: accountName(_accountId),
      isPlaceholder: _accountId == null,
      onTap: () =>
          _pickAccount(accounts, isToAccount: false, currency: currency),
    );
    final toAccountTile = _DetailTile(
      caption: 'To Account',
      value: accountName(_toAccountId),
      isPlaceholder: _toAccountId == null,
      onTap: () =>
          _pickAccount(accounts, isToAccount: true, currency: currency),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isTransfer) ...[
          const _FieldLabel('Category'),
          SizedBox(
            height: Sizes.touchTarget,
            child: categoriesAsync.when(
              data: _buildCategoryChips,
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load')),
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: isTransfer
              ? Column(
                  children: [
                    _DetailsBar(tiles: [accountTile, toAccountTile]),
                    const SizedBox(height: Space.sm),
                    _DetailsBar(tiles: [_dateTile(), _noteTile()]),
                  ],
                )
              : _DetailsBar(tiles: [accountTile, _dateTile(), _noteTile()]),
        ),
      ],
    );
  }

  _DetailTile _dateTile() => _DetailTile(
        caption: 'Date',
        value: AppDateUtils.formatDisplayDate(_date),
        onTap: _pickDate,
      );

  _DetailTile _noteTile() {
    final note = _noteController.text.trim();
    return _DetailTile(
      caption: 'Note (optional)',
      value: note.isEmpty ? 'Add note' : note,
      isPlaceholder: note.isEmpty,
      onTap: _editNote,
    );
  }

  Widget _buildCategoryChips(List<Category> categories) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _ChoicePill(
          label: category.name,
          leading: CategoryIcon(
            emoji: category.icon,
            color: Color(category.color),
            size: 28,
          ),
          selected: category.id == _categoryId,
          onTap: () => setState(() => _categoryId = category.id),
        );
      },
    );
  }

  Future<void> _pickAccount(
    List<Account> accounts, {
    required bool isToAccount,
    required String currency,
  }) async {
    final choices = isToAccount
        // Don't show source account as destination option
        ? accounts.where((a) => a.id != _accountId).toList()
        : accounts;
    final current = isToAccount ? _toAccountId : _accountId;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  0,
                  Space.xl,
                  Space.sm,
                ),
                child: Text(
                  isToAccount
                      ? 'To Account'
                      : (_type == TransactionType.transfer
                          ? 'From Account'
                          : 'Account'),
                  style: text.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Space.lg),
                  children: [
                    for (final account in choices)
                      ListTile(
                        leading: CategoryIcon(
                          emoji: account.icon,
                          color: Color(account.color),
                        ),
                        title: Text(account.name),
                        subtitle: MoneyText(
                          account.currentBalance,
                          currency: currency,
                          semanticLabel: 'Balance',
                          style: text.bodyMedium,
                          color: scheme.onSurfaceVariant,
                        ),
                        trailing: account.id == current
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        selected: account.id == current,
                        onTap: () => Navigator.pop(context, account.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isToAccount) {
          _toAccountId = picked;
        } else {
          _accountId = picked;
        }
      });
    }
  }

  Future<void> _editNote() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
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
            TextField(
              controller: _noteController,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_date),
      );

      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _date.hour,
          time?.minute ?? _date.minute,
        );
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(transactionsProvider.notifier)
                  .deleteTransaction(widget.transactionId!);
              if (mounted) {
                await ref.read(dashboardProvider.notifier).refresh();
                if (mounted) context.pop();
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

  Widget _buildLoanForm() {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Person',
              padding: EdgeInsets.only(bottom: Space.sm)),
          if (!_isCreatingNewPerson)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPersonId,
                    hint: const Text('Select a person'),
                    items: _people
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedPersonId = value);
                    },
                  ),
                ),
                const SizedBox(width: Space.sm),
                IconButton.filledTonal(
                  tooltip: 'Create New Person',
                  onPressed: () {
                    setState(() {
                      _isCreatingNewPerson = true;
                      _selectedPersonId = null;
                    });
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPersonController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter person name',
                      prefixIcon: Icon(Icons.person_add),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                IconButton.filledTonal(
                  tooltip: 'Select Existing Person',
                  onPressed: () {
                    setState(() {
                      _isCreatingNewPerson = false;
                      _newPersonController.clear();
                    });
                  },
                  icon: const Icon(Icons.list),
                ),
              ],
            ),
          const _FieldLabel(
            'Direction',
            padding: EdgeInsets.only(top: Space.md, bottom: Space.sm),
          ),
          Row(
            children: [
              Expanded(
                child: _ChoicePill(
                  label: 'I Lent',
                  leading: Icon(Icons.north_east_rounded,
                      size: 18, color: palette.income),
                  selected: _loanType == LoanType.lent,
                  selectedColor: palette.incomeContainer,
                  selectedForeground: palette.onIncomeContainer,
                  expand: true,
                  onTap: () => setState(() => _loanType = LoanType.lent),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _ChoicePill(
                  label: 'I Borrowed',
                  leading: Icon(Icons.south_west_rounded,
                      size: 18, color: palette.expense),
                  selected: _loanType == LoanType.borrowed,
                  selectedColor: palette.expenseContainer,
                  selectedForeground: palette.onExpenseContainer,
                  expand: true,
                  onTap: () => setState(() => _loanType = LoanType.borrowed),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          _DetailsBar(tiles: [_dateTile(), _noteTile()]),
        ],
      ),
    );
  }

  /// Background and text color of the selected type tab.
  (Color, Color) _typeColors() {
    final palette = context.palette;
    if (_isLoanTab) return (palette.loanContainer, palette.onLoanContainer);
    switch (_type) {
      case TransactionType.expense:
        return (palette.expenseContainer, palette.onExpenseContainer);
      case TransactionType.income:
        return (palette.incomeContainer, palette.onIncomeContainer);
      case TransactionType.transfer:
        return (palette.transferContainer, palette.onTransferContainer);
    }
  }
}

/// Small label above a group of fields.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(
    this.text, {
    this.padding = const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A tonal, selectable pill (categories, loan direction).
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.selectedColor,
    this.selectedForeground,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? selectedColor;
  final Color? selectedForeground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bg = selected
        ? (selectedColor ?? scheme.secondaryContainer)
        : scheme.surfaceContainerHigh;
    final fg = selected
        ? (selectedForeground ?? scheme.onSecondaryContainer)
        : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.standard,
        height: Sizes.touchTarget,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: selected ? fg.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: Radii.mdAll,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: leading != null ? Space.sm : Space.lg,
                right: Space.lg,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Space.sm)
                  ],
                  Text(label, style: text.labelLarge?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable field in a [_DetailsBar]: a caption over its value.
class _DetailTile {
  const _DetailTile({
    required this.caption,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  final String caption;
  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;
}

/// A row of detail fields (account, date, note) in one tonal container.
class _DetailsBar extends StatelessWidget {
  const _DetailsBar({required this.tiles});

  final List<_DetailTile> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  indent: Space.md,
                  endIndent: Space.md,
                  color: scheme.outlineVariant,
                ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: tiles[i].onTap,
                    child: Semantics(
                      button: true,
                      label: '${tiles[i].caption}: ${tiles[i].value}',
                      excludeSemantics: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.md,
                            vertical: Space.sm + 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tiles[i].caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tiles[i].value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall?.copyWith(
                                  color: tiles[i].isPlaceholder
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final accountsWithBalanceProvider = FutureProvider<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getAllWithBalances();
});

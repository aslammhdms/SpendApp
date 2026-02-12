import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../../../data/models/loan.dart';
import '../../../data/models/person.dart';
import '../providers/transactions_provider.dart';
import '../widgets/amount_input_pad.dart';
import '../widgets/category_selector.dart';
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

        if (mounted) {
          await ref.read(dashboardProvider.notifier).refresh();
          await ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Expense'),
            const Tab(text: 'Income'),
            const Tab(text: 'Transfer'),
            if (!isEditing) const Tab(text: 'Loan'),
          ],
          indicatorColor: _getTypeColor(),
          labelColor: _getTypeColor(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Amount Input
                Expanded(
                  flex: 3,
                  child: AmountInputPad(
                    initialAmount: _amount,
                    currency: currency,
                    onAmountChanged: (amount) {
                      setState(() => _amount = amount);
                    },
                  ),
                ),

                // Form Fields
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _isLoanTab
                        ? _buildLoanForm()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Selector (not for transfers)
                              if (_type != TransactionType.transfer) ...[
                                Text(
                                  'Category',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                _type == TransactionType.expense
                                    ? expenseCategoriesAsync.when(
                                        data: (categories) => _buildCategoryChips(categories),
                                        loading: () => const LinearProgressIndicator(),
                                        error: (_, __) => const Text('Failed to load'),
                                      )
                                    : incomeCategoriesAsync.when(
                                        data: (categories) => _buildCategoryChips(categories),
                                        loading: () => const LinearProgressIndicator(),
                                        error: (_, __) => const Text('Failed to load'),
                                      ),
                                const SizedBox(height: 16),
                              ],

                              // Account Selector
                              Text(
                                _type == TransactionType.transfer
                                    ? 'From Account'
                                    : 'Account',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              accountsAsync.when(
                                data: (accounts) => _buildAccountChips(accounts, false),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => const Text('Failed to load'),
                              ),
                              const SizedBox(height: 16),

                              // To Account (for transfers)
                              if (_type == TransactionType.transfer) ...[
                                Text(
                                  'To Account',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                accountsAsync.when(
                                  data: (accounts) => _buildAccountChips(accounts, true),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, __) => const Text('Failed to load'),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Date Picker
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.calendar_today),
                                title: const Text('Date'),
                                subtitle: Text(AppDateUtils.formatDisplayDate(_date)),
                                onTap: _pickDate,
                              ),

                              // Note Field
                              TextField(
                                controller: _noteController,
                                decoration: const InputDecoration(
                                  labelText: 'Note (optional)',
                                  prefixIcon: Icon(Icons.notes),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getTypeColor(),
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<Category> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((category) {
        final isSelected = category.id == _categoryId;
        return FilterChip(
          avatar: Text(category.icon),
          label: Text(category.name),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _categoryId = category.id);
          },
          selectedColor: Color(category.color).withOpacity(0.2),
        );
      }).toList(),
    );
  }

  Widget _buildAccountChips(List<Account> accounts, bool isToAccount) {
    final currentSelection = isToAccount ? _toAccountId : _accountId;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((account) {
        // Don't show source account as destination option
        if (isToAccount && account.id == _accountId) {
          return const SizedBox.shrink();
        }

        final isSelected = account.id == currentSelection;
        return FilterChip(
          avatar: Text(account.icon),
          label: Text(account.name),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              if (isToAccount) {
                _toAccountId = account.id;
              } else {
                _accountId = account.id;
              }
            });
          },
          selectedColor: Color(account.color).withOpacity(0.2),
        );
      }).toList(),
    );
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
        content: const Text('Are you sure you want to delete this transaction?'),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Person picker
        Text(
          'Person',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (!_isCreatingNewPerson) ...[
          DropdownButtonFormField<String>(
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
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isCreatingNewPerson = true;
                _selectedPersonId = null;
              });
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Create New Person'),
          ),
        ] else ...[
          TextField(
            controller: _newPersonController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter person name',
              prefixIcon: Icon(Icons.person_add),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isCreatingNewPerson = false;
                _newPersonController.clear();
              });
            },
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Select Existing Person'),
          ),
        ],
        const SizedBox(height: 16),

        // Lent / Borrowed direction
        Text(
          'Direction',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('I Lent'),
                selected: _loanType == LoanType.lent,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _loanType = LoanType.lent);
                  }
                },
                selectedColor: AppColors.income.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('I Borrowed'),
                selected: _loanType == LoanType.borrowed,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _loanType = LoanType.borrowed);
                  }
                },
                selectedColor: AppColors.expense.withOpacity(0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Date Picker
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: const Text('Date'),
          subtitle: Text(AppDateUtils.formatDisplayDate(_date)),
          onTap: _pickDate,
        ),

        // Note Field
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Color _getTypeColor() {
    if (_isLoanTab) return AppColors.loan;
    switch (_type) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.transfer:
        return AppColors.transfer;
    }
  }
}

final accountsWithBalanceProvider = FutureProvider<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return await repository.getAllWithBalances();
});

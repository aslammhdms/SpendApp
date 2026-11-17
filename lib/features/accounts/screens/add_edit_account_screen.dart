import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/category_defaults.dart';
import '../../../data/models/account.dart';
import '../providers/accounts_provider.dart';
import '../../home/providers/dashboard_provider.dart';

class AddEditAccountScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const AddEditAccountScreen({
    super.key,
    this.accountId,
  });

  @override
  ConsumerState<AddEditAccountScreen> createState() =>
      _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends ConsumerState<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.bank;
  String _icon = '🏦';
  int _color = 0xFF2196F3;
  String _currency = 'USD';
  bool _isLoading = false;
  Account? _existingAccount;

  bool get isEditing => widget.accountId != null;

  final List<String> _accountIcons = [
    '💵', '🏦', '💳', '💰', '🏧', '📈', '🪙', '💎',
  ];

  final List<int> _accountColors = [
    0xFF4CAF50, 0xFF2196F3, 0xFFF44336, 0xFF9C27B0,
    0xFFFF9800, 0xFF00BCD4, 0xFF795548, 0xFF607D8B,
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadAccount();
    }
  }

  Future<void> _loadAccount() async {
    setState(() => _isLoading = true);
    final repository = ref.read(accountRepositoryProvider);
    final account = await repository.getById(widget.accountId!);

    if (account != null && mounted) {
      setState(() {
        _existingAccount = account;
        _nameController.text = account.name;
        _balanceController.text = account.initialBalance.toString();
        _type = account.type;
        _icon = account.icon;
        _color = account.color;
        _currency = account.currency;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = double.tryParse(_balanceController.text) ?? 0;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(accountsProvider.notifier);

      if (isEditing && _existingAccount != null) {
        await notifier.updateAccount(
          _existingAccount!.copyWith(
            name: _nameController.text.trim(),
            type: _type,
            initialBalance: balance,
            currency: _currency,
            icon: _icon,
            color: _color,
          ),
        );
      } else {
        await notifier.createAccount(
          name: _nameController.text.trim(),
          type: _type,
          initialBalance: balance,
          currency: _currency,
          icon: _icon,
          color: _color,
        );
      }

      if (mounted) {
        await ref.read(accountsProvider.notifier).loadAccounts();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Account' : 'New Account'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isLoading && isEditing
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Preview
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Color(_color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                _icon,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Account Name'
                                      : _nameController.text,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  _getAccountTypeLabel(_type),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Initial Balance
                  TextFormField(
                    controller: _balanceController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Balance',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),

                  // Account Type
                  Text(
                    'Account Type',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AccountType.values.map((type) {
                      return ChoiceChip(
                        label: Text(_getAccountTypeLabel(type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Icon
                  Text(
                    'Icon',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _accountIcons.map((icon) {
                      return GestureDetector(
                        onTap: () => setState(() => _icon = icon),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _icon == icon
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: _icon == icon
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(icon, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Color
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _accountColors.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(color),
                            borderRadius: BorderRadius.circular(12),
                            border: _color == color
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: _color == color
                                ? [
                                    BoxShadow(
                                      color: Color(color).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: _color == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAccount,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update' : 'Create Account'),
                  ),
                ],
              ),
            ),
    );
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.credit:
        return 'Credit Card';
      case AccountType.savings:
        return 'Savings';
      case AccountType.investment:
        return 'Investment';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.other:
        return 'Other';
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(accountsProvider.notifier)
                  .deleteAccount(widget.accountId!);
              if (mounted) context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

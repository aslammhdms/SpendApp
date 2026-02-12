import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/account.dart';
import '../providers/transactions_provider.dart';

class FilterSheet extends StatefulWidget {
  final TransactionFilter currentFilter;
  final List<Category> categories;
  final List<Account> accounts;
  final ValueChanged<TransactionFilter> onApply;

  const FilterSheet({
    super.key,
    required this.currentFilter,
    required this.categories,
    required this.accounts,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late TransactionFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_filter.hasFilters)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filter = const TransactionFilter();
                    });
                  },
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Transaction Type
          Text(
            'Type',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeChip(null, 'All'),
              _buildTypeChip(TransactionType.expense, 'Expense'),
              _buildTypeChip(TransactionType.income, 'Income'),
              _buildTypeChip(TransactionType.transfer, 'Transfer'),
              _buildLoanChip(),
            ],
          ),
          const SizedBox(height: 20),

          // Date Range
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: 'From',
                  date: _filter.startDate,
                  onDateSelected: (date) {
                    setState(() {
                      _filter = _filter.copyWith(startDate: date);
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerButton(
                  label: 'To',
                  date: _filter.endDate,
                  onDateSelected: (date) {
                    setState(() {
                      _filter = _filter.copyWith(endDate: date);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category
          if (widget.categories.isNotEmpty) ...[
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCategoryChip(null, 'All', null);
                  }
                  final category = widget.categories[index - 1];
                  return _buildCategoryChip(
                    category.id,
                    category.name,
                    category.icon,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Account
          if (widget.accounts.isNotEmpty) ...[
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.accounts.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAccountChip(null, 'All', null);
                  }
                  final account = widget.accounts[index - 1];
                  return _buildAccountChip(
                    account.id,
                    account.name,
                    account.icon,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_filter);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTypeChip(TransactionType? type, String label) {
    final isSelected = type == null
        ? _filter.type == null && !_filter.showLoansOnly
        : _filter.type == type && !_filter.showLoansOnly;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (type == null) {
            _filter = _filter.clearField('type').clearField('showLoansOnly');
          } else {
            _filter = _filter.copyWith(type: type, showLoansOnly: false);
          }
        });
      },
    );
  }

  Widget _buildLoanChip() {
    final isSelected = _filter.showLoansOnly;
    return FilterChip(
      label: const Text('Loan'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filter = _filter.clearField('type').copyWith(showLoansOnly: true);
        });
      },
    );
  }

  Widget _buildCategoryChip(String? categoryId, String label, String? icon) {
    final isSelected = _filter.categoryId == categoryId;
    return FilterChip(
      avatar: icon != null ? Text(icon) : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (categoryId == null) {
            _filter = _filter.clearField('categoryId');
          } else {
            _filter = _filter.copyWith(categoryId: categoryId);
          }
        });
      },
    );
  }

  Widget _buildAccountChip(String? accountId, String label, String? icon) {
    final isSelected = _filter.accountId == accountId;
    return FilterChip(
      avatar: icon != null ? Text(icon) : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (accountId == null) {
            _filter = _filter.clearField('accountId');
          } else {
            _filter = _filter.copyWith(accountId: accountId);
          }
        });
      },
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onDateSelected;

  const _DatePickerButton({
    required this.label,
    this.date,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date != null
                ? '${date!.day}/${date!.month}/${date!.year}'
                : label,
            style: TextStyle(
              color: date != null
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
          const Icon(Icons.calendar_today, size: 18),
        ],
      ),
    );
  }
}

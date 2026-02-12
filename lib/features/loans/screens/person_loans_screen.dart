import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/person.dart';
import '../providers/loans_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../widgets/loan_tile.dart';
import '../../settings/providers/settings_provider.dart';

class PersonLoansScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonLoansScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonLoansScreen> createState() => _PersonLoansScreenState();
}

class _PersonLoansScreenState extends ConsumerState<PersonLoansScreen> {
  Person? _person;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final personRepo = ref.read(personRepositoryProvider);
    final person = await personRepo.getById(widget.personId);
    if (person != null && mounted) {
      final loanRepo = ref.read(loanRepositoryProvider);
      final balance = await loanRepo.getPersonBalance(widget.personId);
      setState(() {
        _person = person.copyWith(netBalance: balance);
      });
    }
    ref.read(loansProvider.notifier).loadPersonLoans(widget.personId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loansProvider);
    final currency = ref.watch(settingsProvider).currency;
    final person = _person;

    return Scaffold(
      appBar: AppBar(
        title: Text(person?.name ?? 'Loading...'),
        actions: [
          if (person != null && person.netBalance != 0)
            TextButton(
              onPressed: () async {
                await context.push('/loans/add/${widget.personId}?settle=true');
                if (mounted) _loadData();
              },
              child: const Text('Settle Up'),
            ),
          if (person != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeletePerson();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Person'),
                ),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(state.error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Balance summary card
                    if (person != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'Net Balance',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textTertiary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyUtils.format(
                                  person.netBalance.abs(),
                                  currencyCode: currency,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: person.netBalance > 0
                                          ? AppColors.income
                                          : person.netBalance < 0
                                              ? AppColors.expense
                                              : AppColors.textTertiary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                person.netBalance > 0
                                    ? '${person.name} owes you'
                                    : person.netBalance < 0
                                        ? 'You owe ${person.name}'
                                        : 'All settled',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'History',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (state.currentPersonLoans.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              const Text('No loans yet'),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: state.currentPersonLoans
                              .map((loan) => LoanTile(
                                    loan: loan,
                                    currency: currency,
                                  ))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/loans/add/${widget.personId}');
          if (mounted) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
    );
  }

  void _confirmDeletePerson() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: const Text(
            'Are you sure? This will hide this person and their loan history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(loansProvider.notifier).deletePerson(widget.personId);
              if (mounted) {
                await ref.read(dashboardProvider.notifier).refresh();
                if (mounted) this.context.pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

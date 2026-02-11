import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../providers/loans_provider.dart';
import '../widgets/person_balance_card.dart';
import '../../settings/providers/settings_provider.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loansProvider.notifier).loadPeople();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loansProvider);
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans & Debts'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(state.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(loansProvider.notifier).loadPeople(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(loansProvider.notifier).loadPeople();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary header
                      Card(
                        color: AppColors.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _SummaryColumn(
                                    label: 'Owed to you',
                                    amount: state.totalOwedToYou,
                                    currency: currency,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white24,
                                  ),
                                  _SummaryColumn(
                                    label: 'You owe',
                                    amount: state.totalYouOwe,
                                    currency: currency,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 12),
                              Text(
                                'Net: ${CurrencyUtils.format(state.totalOwedToYou - state.totalYouOwe, currencyCode: currency)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'People',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (state.people.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: AppColors.textTertiary),
                                const SizedBox(height: 12),
                                const Text('No people yet'),
                                const SizedBox(height: 4),
                                Text(
                                  'Add a loan to get started',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...state.people.map((person) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PersonBalanceCard(
                                person: person,
                                currency: currency,
                                onTap: () => context
                                    .push('/loans/person/${person.id}'),
                              ),
                            )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/loans/add');
          if (mounted) {
            ref.read(loansProvider.notifier).loadPeople();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;

  const _SummaryColumn({
    required this.label,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.format(amount, currencyCode: currency),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

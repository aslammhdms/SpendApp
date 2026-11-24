import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_stat.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/person.dart';
import '../providers/loans_provider.dart';
import '../widgets/person_balance_card.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/glass_dialog.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../shared/widgets/glass_app_bar.dart';

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
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('Loans & Debts'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(state.error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.read(loansProvider.notifier).loadPeople(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  edgeOffset: ScreenInsets.topOf(context),
                  onRefresh: () async {
                    await ref.read(loansProvider.notifier).loadPeople();
                  },
                  child: ListView(
                    padding: ScreenInsets.of(
                      context,
                      bottom: Space.fabClearance,
                    ),
                    children: [
                      _LoansSummary(
                        owedToYou: state.totalOwedToYou,
                        youOwe: state.totalYouOwe,
                        currency: currency,
                      ),
                      OverlineHeader(
                        'People',
                        trailing: state.people.isNotEmpty
                            ? Text(
                                'Swipe left to delete',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              )
                            : null,
                      ),
                      if (state.people.isEmpty)
                        const Card(
                          margin: EdgeInsets.zero,
                          child: EmptyState(
                            icon: Icons.people_outline,
                            title: 'No people yet',
                            subtitle: 'Add a loan to get started',
                            compact: true,
                          ),
                        )
                      else
                        ...state.people.map((person) => Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: PersonBalanceCard(
                                person: person,
                                currency: currency,
                                onTap: () async {
                                  await context
                                      .push('/loans/person/${person.id}');
                                  if (mounted) {
                                    ref
                                        .read(loansProvider.notifier)
                                        .loadPeople();
                                  }
                                },
                                onDelete: () => _confirmDeletePerson(person),
                              ),
                            )),
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

  void _confirmDeletePerson(Person person) {
    showDialog(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Delete Person'),
        content: Text(
            'Are you sure? This will hide ${person.name} and their loan history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(loansProvider.notifier).deletePerson(person.id);
              if (mounted) {
                ref.read(syncEngineProvider).sync();
                await ref.read(dashboardProvider.notifier).refresh();
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

class _LoansSummary extends StatelessWidget {
  final double owedToYou;
  final double youOwe;
  final String currency;

  const _LoansSummary({
    required this.owedToYou,
    required this.youOwe,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final net = owedToYou - youOwe;
    final netText = CurrencyUtils.format(net, currencyCode: currency);

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: Radii.xlAll,
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net balance',
            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Semantics(
            label: 'Net: $netText',
            excludeSemantics: true,
            child: Text(netText, style: text.headlineMedium?.tabular),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: SignalStat(
                  label: 'Owed to you',
                  amount: owedToYou,
                  kind: MoneyKind.income,
                  currency: currency,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: SignalStat(
                  label: 'You owe',
                  amount: youOwe,
                  kind: MoneyKind.expense,
                  currency: currency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

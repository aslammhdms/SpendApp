import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/category.dart';
import '../../transactions/providers/transactions_provider.dart';

class CategoryPieChart extends ConsumerWidget {
  final Map<String, double> categoryTotals;
  final double totalAmount;
  final String currency;

  const CategoryPieChart({
    super.key,
    required this.categoryTotals,
    required this.totalAmount,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    if (categoryTotals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: 16),
              Text(
                'No spending data',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return categoriesAsync.when(
      data: (categories) => _buildChart(context, categories),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildChart(context, []),
    );
  }

  Widget _buildChart(BuildContext context, List<Category> categories) {
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedEntries.take(5).toList();
    final otherTotal = sortedEntries.skip(5).fold(0.0, (sum, e) => sum + e.value);

    if (otherTotal > 0) {
      topCategories.add(MapEntry('other', otherTotal));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending by Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: List.generate(topCategories.length, (index) {
                          final entry = topCategories[index];
                          final category = categories.firstWhere(
                            (c) => c.id == entry.key,
                            orElse: () => Category(
                              id: 'other',
                              name: 'Other',
                              type: CategoryType.expense,
                              icon: '...',
                              color: 0xFF808080,
                              sortOrder: 0,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          );

                          final percent = (entry.value / totalAmount * 100);
                          final color = entry.key == 'other'
                              ? Colors.grey
                              : Color(category.color);

                          return PieChartSectionData(
                            color: color,
                            value: entry.value,
                            title: '${percent.toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: topCategories.map((entry) {
                        final category = categories.firstWhere(
                          (c) => c.id == entry.key,
                          orElse: () => Category(
                            id: 'other',
                            name: 'Other',
                            type: CategoryType.expense,
                            icon: '...',
                            color: 0xFF808080,
                            sortOrder: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: entry.key == 'other'
                                      ? Colors.grey
                                      : Color(category.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key == 'other' ? 'Other' : category.name,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            // Top categories list
            ...topCategories.take(5).map((entry) {
              final category = categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => Category(
                  id: 'other',
                  name: 'Other',
                  type: CategoryType.expense,
                  icon: '?',
                  color: 0xFF808080,
                  sortOrder: 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              final percent = (entry.value / totalAmount * 100);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      category.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: percent / 100,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(category.color),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtils.format(
                            entry.value,
                            currencyCode: currency,
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

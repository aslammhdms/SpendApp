import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/utils/currency_utils.dart';

class IncomeExpenseBarChart extends StatelessWidget {
  final Map<DateTime, double> monthlyExpenses;
  final Map<DateTime, double> monthlyIncome;
  final String currency;

  const IncomeExpenseBarChart({
    super.key,
    required this.monthlyExpenses,
    required this.monthlyIncome,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final axisStyle = text.labelSmall!.tabular.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );

    if (monthlyExpenses.isEmpty && monthlyIncome.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        title: 'No data for this period',
        compact: true,
      );
    }

    final months = monthlyExpenses.keys.toList()..sort();
    final maxValue = [
      ...monthlyExpenses.values,
      ...monthlyIncome.values,
    ].fold(0.0, (max, val) => val > max ? val : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Income vs Expense',
                  style: text.titleMedium,
                ),
                Row(
                  children: [
                    _buildLegendItem(context, palette.income, 'Income'),
                    const SizedBox(width: 16),
                    _buildLegendItem(context, palette.expense, 'Expense'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: scheme.inverseSurface,
                      tooltipRoundedRadius: Radii.sm,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: Space.sm,
                      ),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = months[group.x.toInt()];
                        final isIncome = rodIndex == 0;
                        final value = isIncome
                            ? monthlyIncome[month] ?? 0
                            : monthlyExpenses[month] ?? 0;
                        return BarTooltipItem(
                          '${_getMonthName(month)}\n',
                          text.labelMedium!
                              .copyWith(color: scheme.onInverseSurface),
                          children: [
                            TextSpan(
                              text:
                                  '${isIncome ? 'Income' : 'Expense'}: ${CurrencyUtils.format(value, currencyCode: currency)}',
                              style: text.titleSmall!.tabular
                                  .copyWith(color: scheme.onInverseSurface),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= months.length) {
                            return const SizedBox();
                          }
                          final month = months[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _getShortMonthName(month),
                              style: axisStyle,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxValue > 0 ? maxValue / 4 : 25,
                        getTitlesWidget: (value, meta) {
                          // Skip the chart's own max, which isn't on the grid
                          // and would collide with the label below it.
                          if (value == meta.max) return const SizedBox();
                          return Text(
                            CurrencyUtils.formatCompact(
                              value,
                              currencyCode: currency,
                            ),
                            style: axisStyle,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 0 ? maxValue / 4 : 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  barGroups: List.generate(months.length, (index) {
                    final month = months[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: monthlyIncome[month] ?? 0,
                          color: palette.income,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: monthlyExpenses[month] ?? 0,
                          color: palette.expense,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs + 2),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[date.month - 1];
  }

  String _getShortMonthName(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }
}

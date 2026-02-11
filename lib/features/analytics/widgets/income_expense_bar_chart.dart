import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
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
    if (monthlyExpenses.isEmpty && monthlyIncome.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.bar_chart,
                size: 64,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: 16),
              Text(
                'No data for this period',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    final months = monthlyExpenses.keys.toList()..sort();
    final maxValue = [
      ...monthlyExpenses.values,
      ...monthlyIncome.values,
    ].fold(0.0, (max, val) => val > max ? val : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Income vs Expense',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Row(
                  children: [
                    _buildLegendItem(AppColors.income, 'Income'),
                    const SizedBox(width: 16),
                    _buildLegendItem(AppColors.expense, 'Expense'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                      tooltipBgColor: AppColors.textPrimary,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = months[group.x.toInt()];
                        final isIncome = rodIndex == 0;
                        final value = isIncome
                            ? monthlyIncome[month] ?? 0
                            : monthlyExpenses[month] ?? 0;
                        return BarTooltipItem(
                          '${_getMonthName(month)}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${isIncome ? 'Income' : 'Expense'}: ${CurrencyUtils.format(value, currencyCode: currency)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
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
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            CurrencyUtils.formatCompact(
                              value,
                              currencyCode: currency,
                            ),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
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
                      color: AppColors.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: List.generate(months.length, (index) {
                    final month = months[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: monthlyIncome[month] ?? 0,
                          color: AppColors.income,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: monthlyExpenses[month] ?? 0,
                          color: AppColors.expense,
                          width: 12,
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
  }

  String _getShortMonthName(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }
}

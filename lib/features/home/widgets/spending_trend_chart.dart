import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';

class SpendingTrendChart extends StatelessWidget {
  final Map<DateTime, double> dailySpending;
  final String currency;

  const SpendingTrendChart({
    super.key,
    required this.dailySpending,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sortedDates = dailySpending.keys.toList()..sort();
    final maxSpending = dailySpending.values.isEmpty
        ? 100.0
        : dailySpending.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxSpending <= 0 ? 100.0 : maxSpending * 1.15;
    final total = dailySpending.values.fold<double>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.lg,
          Space.xl,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Spending Trend', style: text.titleMedium),
                  ),
                ),
                Text(
                  'Last 7 days',
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            SizedBox(
              height: 168,
              child: sortedDates.isEmpty
                  ? Center(
                      child: Text(
                        'No spending data yet',
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : Semantics(
                      label: 'Spending over the last 7 days: '
                          '${CurrencyUtils.format(total, currencyCode: currency)} in total',
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
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
                              tooltipMargin: Space.sm,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final date = sortedDates[group.x.toInt()];
                                final amount = dailySpending[date] ?? 0;
                                return BarTooltipItem(
                                  '${_getDayName(date)}\n',
                                  text.labelMedium!.copyWith(
                                    color: scheme.onInverseSurface,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: CurrencyUtils.format(
                                        amount,
                                        currencyCode: currency,
                                      ),
                                      style: text.titleSmall!.tabular.copyWith(
                                        color: scheme.onInverseSurface,
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
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= sortedDates.length) {
                                    return const SizedBox();
                                  }
                                  final date = sortedDates[value.toInt()];
                                  final today = _isToday(date);
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: Space.sm),
                                    child: Text(
                                      _getShortDayName(date),
                                      style: text.labelMedium?.copyWith(
                                        color: today
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant,
                                        fontWeight:
                                            today ? FontWeight.w700 : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
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
                            horizontalInterval: maxY / 3,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.6),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          barGroups: List.generate(sortedDates.length, (index) {
                            final date = sortedDates[index];
                            final amount = dailySpending[date] ?? 0;
                            final isToday = _isToday(date);
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: amount,
                                  color: isToday
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.45),
                                  width: 22,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(Radii.sm),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        swapAnimationDuration: Motion.slow,
                        swapAnimationCurve: Motion.standard,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _getShortDayName(DateTime date) {
    if (_isToday(date)) return 'Today';
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[date.weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/utils/currency_utils.dart';

class SpendingLineChart extends StatelessWidget {
  final Map<DateTime, double> dailySpending;
  final String currency;

  const SpendingLineChart({
    super.key,
    required this.dailySpending,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final axisStyle = text.labelSmall!.tabular.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
    final sortedDates = dailySpending.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No spending data',
        compact: true,
      );
    }

    final maxY = dailySpending.values.isEmpty
        ? 100.0
        : dailySpending.values.reduce((a, b) => a > b ? a : b) * 1.2;

    final spots = List.generate(sortedDates.length, (index) {
      final date = sortedDates[index];
      return FlSpot(index.toDouble(), dailySpending[date] ?? 0);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Spending',
              style: text.titleMedium,
            ),
            const SizedBox(height: Space.xl),
            SizedBox(
              height: 200,
              child: Semantics(
                label: 'Daily spending chart, ${sortedDates.length} days',
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: scheme.inverseSurface,
                        tooltipRoundedRadius: Radii.sm,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: Space.sm,
                        ),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final date = sortedDates[spot.x.toInt()];
                            return LineTooltipItem(
                              '${date.day}/${date.month}\n',
                              text.labelMedium!
                                  .copyWith(color: scheme.onInverseSurface),
                              children: [
                                TextSpan(
                                  text: CurrencyUtils.format(
                                    spot.y,
                                    currencyCode: currency,
                                  ),
                                  style: text.titleSmall!.tabular
                                      .copyWith(color: scheme.onInverseSurface),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: (sortedDates.length / 5).ceil().toDouble(),
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= sortedDates.length) {
                              return const SizedBox();
                            }
                            final date = sortedDates[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date.day}/${date.month}',
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
                          interval: maxY > 0 ? maxY / 4 : 25,
                          getTitlesWidget: (value, meta) {
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: scheme.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        preventCurveOverShooting: true,
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, _) =>
                              spot.x == spots.length - 1,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: scheme.primary,
                            strokeWidth: 2,
                            strokeColor: scheme.surfaceContainerLow,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scheme.primary.withValues(alpha: 0.22),
                              scheme.primary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: Motion.slow,
                  curve: Motion.standard,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../transactions/providers/transactions_provider.dart';

/// Donut of spending by category with a ranked list underneath.
///
/// Slices take the palette's chart colors by rank, so neighbors never
/// look alike; the list rows use the same colors and double as the legend.
class CategoryPieChart extends ConsumerStatefulWidget {
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
  ConsumerState<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _Slice {
  const _Slice(this.id, this.name, this.icon, this.amount, this.color);
  final String id;
  final String name;
  final String icon;
  final double amount;
  final Color color;
}

class _CategoryPieChartState extends ConsumerState<CategoryPieChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    if (widget.categoryTotals.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No spending data',
        compact: true,
      );
    }

    return categoriesAsync.when(
      data: (categories) => _buildChart(context, categories),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildChart(context, []),
    );
  }

  List<_Slice> _slices(BuildContext context, List<Category> categories) {
    final palette = context.palette;
    final sorted = widget.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final otherTotal = sorted.skip(5).fold(0.0, (sum, e) => sum + e.value);

    final slices = <_Slice>[];
    for (var i = 0; i < top.length; i++) {
      final entry = top[i];
      Category? category;
      for (final c in categories) {
        if (c.id == entry.key) category = c;
      }
      slices.add(_Slice(
        entry.key,
        category?.name ?? 'Other',
        category?.icon ?? '',
        entry.value,
        palette.chartColor(i),
      ));
    }
    if (otherTotal > 0) {
      slices.add(_Slice('other', 'Other', '', otherTotal, palette.chartOther));
    }
    return slices;
  }

  Widget _buildChart(BuildContext context, List<Category> categories) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final slices = _slices(context, categories);
    final total = widget.totalAmount;
    String percentOf(double v, int digits) =>
        total > 0 ? '${(v / total * 100).toStringAsFixed(digits)}%' : '0%';

    final touched = _touched;
    final center =
        touched != null && touched < slices.length ? slices[touched] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Spending by Category', style: text.titleMedium),
            ),
            const SizedBox(height: Space.lg),
            Semantics(
              label:
                  'Spending by category: ${slices.map((s) => '${s.name} ${percentOf(s.amount, 0)}').join(', ')}',
              child: SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 66,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            final index =
                                response?.touchedSection?.touchedSectionIndex;
                            if (!event.isInterestedForInteractions ||
                                index == null ||
                                index < 0) {
                              if (_touched != null) {
                                setState(() => _touched = null);
                              }
                              return;
                            }
                            if (index != _touched) {
                              setState(() => _touched = index);
                            }
                          },
                        ),
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            PieChartSectionData(
                              color: touched == null || touched == i
                                  ? slices[i].color
                                  : slices[i].color.withValues(alpha: 0.35),
                              value: slices[i].amount,
                              showTitle: false,
                              radius: touched == i ? 30 : 24,
                            ),
                        ],
                      ),
                      swapAnimationDuration: Motion.medium,
                      swapAnimationCurve: Motion.standard,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          center?.name ?? 'Spent',
                          style: text.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          CurrencyUtils.format(
                            center?.amount ?? total,
                            currencyCode: widget.currency,
                          ),
                          style: text.titleMedium?.tabular,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            for (var i = 0; i < slices.length; i++)
              _CategoryRow(
                slice: slices[i],
                percentLabel: percentOf(slices[i].amount, 1),
                fraction: total > 0 ? slices[i].amount / total : 0,
                currency: widget.currency,
                highlighted: touched == i,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slice,
    required this.percentLabel,
    required this.fraction,
    required this.currency,
    required this.highlighted,
  });

  final _Slice slice;
  final String percentLabel;
  final double fraction;
  final String currency;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = CurrencyUtils.format(slice.amount, currencyCode: currency);
    return Semantics(
      label: '${slice.name}, $amount, $percentLabel',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: highlighted ? scheme.surfaceContainerHigh : null,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            slice.icon.isEmpty
                ? Container(
                    width: Sizes.iconCircleSmall,
                    height: Sizes.iconCircleSmall,
                    decoration: BoxDecoration(
                      color: slice.color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.more_horiz, size: 18, color: slice.color),
                  )
                : CategoryIcon(
                    emoji: slice.icon,
                    color: slice.color,
                    size: Sizes.iconCircleSmall,
                  ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slice.name,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(amount, style: text.titleSmall?.tabular),
                    ],
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          color: slice.color,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      SizedBox(
                        width: 48,
                        child: Text(
                          percentLabel,
                          textAlign: TextAlign.right,
                          style: text.labelMedium?.tabular
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

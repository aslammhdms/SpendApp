import 'package:flutter/material.dart';

/// App-specific colors that Material's [ColorScheme] has no role for:
/// money signals, budget states and the chart palette.
///
/// Read it with `context.palette` (see [AppPaletteContext]); never use
/// raw colors in widgets. Every text color here meets WCAG AA (4.5:1) on
/// the surface, surfaceContainerLow and surfaceContainerHigh of its
/// theme, and every chart color meets 3:1 against card surfaces.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.income,
    required this.incomeContainer,
    required this.onIncomeContainer,
    required this.expense,
    required this.expenseContainer,
    required this.onExpenseContainer,
    required this.transfer,
    required this.transferContainer,
    required this.onTransferContainer,
    required this.loan,
    required this.loanContainer,
    required this.onLoanContainer,
    required this.budgetSafe,
    required this.budgetWarning,
    required this.budgetDanger,
    required this.chart,
    required this.chartOther,
    required this.raisedSurface,
    required this.cardShadow,
  });

  /// Money in: income amounts, "owed to you".
  final Color income;
  final Color incomeContainer;
  final Color onIncomeContainer;

  /// Money out: expense amounts, "you owe".
  final Color expense;
  final Color expenseContainer;
  final Color onExpenseContainer;

  /// Moves between your own accounts.
  final Color transfer;
  final Color transferContainer;
  final Color onTransferContainer;

  /// Loans and settlements with people.
  final Color loan;
  final Color loanContainer;
  final Color onLoanContainer;

  /// Budget progress below 80%, from 80%, and at 100% or more.
  final Color budgetSafe;
  final Color budgetWarning;
  final Color budgetDanger;

  /// Categorical colors for chart series, in order of use. Charts show at
  /// most [chart.length] series and fold the rest into [chartOther].
  final List<Color> chart;
  final Color chartOther;

  /// Background of raised cards (the hero card). White with a soft shadow
  /// in light mode; a lighter tone in dark mode, where depth reads as
  /// lightness rather than shadow.
  final Color raisedSurface;

  /// Soft shadow for raised cards (the hero card, sheets).
  final Color cardShadow;

  static AppPalette light(ColorScheme scheme) => AppPalette(
        income: const Color(0xFF047552),
        incomeContainer: const Color(0xFFD1FAE5),
        onIncomeContainer: const Color(0xFF065F46),
        expense: const Color(0xFFB91C1C),
        expenseContainer: const Color(0xFFFEE2E2),
        onExpenseContainer: const Color(0xFF991B1B),
        transfer: scheme.primary,
        transferContainer: const Color(0xFFE0E7FF),
        onTransferContainer: const Color(0xFF3730A3),
        loan: const Color(0xFF6D28D9),
        loanContainer: const Color(0xFFEDE9FE),
        onLoanContainer: const Color(0xFF5B21B6),
        budgetSafe: const Color(0xFF047552),
        budgetWarning: const Color(0xFFA14A07),
        budgetDanger: const Color(0xFFB91C1C),
        chart: const [
          Color(0xFF4F46E5), // indigo
          Color(0xFF0F766E), // teal
          Color(0xFFB45309), // amber
          Color(0xFFE11D48), // rose
          Color(0xFF0284C7), // sky
          Color(0xFF7C3AED), // violet
          Color(0xFF4D7C0F), // lime
          Color(0xFFC026D3), // fuchsia
        ],
        chartOther: const Color(0xFF64748B),
        raisedSurface: scheme.surfaceContainerLowest,
        cardShadow: const Color(0x141B1B3A),
      );

  static AppPalette dark(ColorScheme scheme) => AppPalette(
        income: const Color(0xFF34D399),
        incomeContainer: const Color(0xFF064E3B),
        onIncomeContainer: const Color(0xFFA7F3D0),
        expense: const Color(0xFFF87171),
        expenseContainer: const Color(0xFF7F1D1D),
        onExpenseContainer: const Color(0xFFFECACA),
        transfer: scheme.primary,
        transferContainer: const Color(0xFF312E81),
        onTransferContainer: const Color(0xFFC7D2FE),
        loan: const Color(0xFFC4B5FD),
        loanContainer: const Color(0xFF4C1D95),
        onLoanContainer: const Color(0xFFDDD6FE),
        budgetSafe: const Color(0xFF34D399),
        budgetWarning: const Color(0xFFFBBF24),
        budgetDanger: const Color(0xFFF87171),
        chart: const [
          Color(0xFF818CF8), // indigo
          Color(0xFF2DD4BF), // teal
          Color(0xFFFBBF24), // amber
          Color(0xFFFB7185), // rose
          Color(0xFF38BDF8), // sky
          Color(0xFFA78BFA), // violet
          Color(0xFFA3E635), // lime
          Color(0xFFE879F9), // fuchsia
        ],
        chartOther: const Color(0xFF64748B),
        raisedSurface: scheme.surfaceContainerHigh,
        cardShadow: const Color(0x66000000),
      );

  /// Budget color for a fraction of the budget used (0.85 = 85%).
  Color budgetColor(double used) {
    if (used >= 1.0) return budgetDanger;
    if (used >= 0.8) return budgetWarning;
    return budgetSafe;
  }

  /// Chart color for the series at [index]; the overflow uses [chartOther].
  Color chartColor(int index) =>
      index < chart.length ? chart[index] : chartOther;

  @override
  AppPalette copyWith({
    Color? income,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? expense,
    Color? expenseContainer,
    Color? onExpenseContainer,
    Color? transfer,
    Color? transferContainer,
    Color? onTransferContainer,
    Color? loan,
    Color? loanContainer,
    Color? onLoanContainer,
    Color? budgetSafe,
    Color? budgetWarning,
    Color? budgetDanger,
    List<Color>? chart,
    Color? chartOther,
    Color? raisedSurface,
    Color? cardShadow,
  }) {
    return AppPalette(
      income: income ?? this.income,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
      expense: expense ?? this.expense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      onExpenseContainer: onExpenseContainer ?? this.onExpenseContainer,
      transfer: transfer ?? this.transfer,
      transferContainer: transferContainer ?? this.transferContainer,
      onTransferContainer: onTransferContainer ?? this.onTransferContainer,
      loan: loan ?? this.loan,
      loanContainer: loanContainer ?? this.loanContainer,
      onLoanContainer: onLoanContainer ?? this.onLoanContainer,
      budgetSafe: budgetSafe ?? this.budgetSafe,
      budgetWarning: budgetWarning ?? this.budgetWarning,
      budgetDanger: budgetDanger ?? this.budgetDanger,
      chart: chart ?? this.chart,
      chartOther: chartOther ?? this.chartOther,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      income: c(income, other.income),
      incomeContainer: c(incomeContainer, other.incomeContainer),
      onIncomeContainer: c(onIncomeContainer, other.onIncomeContainer),
      expense: c(expense, other.expense),
      expenseContainer: c(expenseContainer, other.expenseContainer),
      onExpenseContainer: c(onExpenseContainer, other.onExpenseContainer),
      transfer: c(transfer, other.transfer),
      transferContainer: c(transferContainer, other.transferContainer),
      onTransferContainer: c(onTransferContainer, other.onTransferContainer),
      loan: c(loan, other.loan),
      loanContainer: c(loanContainer, other.loanContainer),
      onLoanContainer: c(onLoanContainer, other.onLoanContainer),
      budgetSafe: c(budgetSafe, other.budgetSafe),
      budgetWarning: c(budgetWarning, other.budgetWarning),
      budgetDanger: c(budgetDanger, other.budgetDanger),
      chart: [
        for (var i = 0; i < chart.length; i++)
          c(chart[i], other.chart[i % other.chart.length]),
      ],
      chartOther: c(chartOther, other.chartOther),
      raisedSurface: c(raisedSurface, other.raisedSurface),
      cardShadow: c(cardShadow, other.cardShadow),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The app palette of the current theme. Falls back to one built from
  /// the active color scheme when the theme has no [AppPalette] (for
  /// example a bare MaterialApp in a widget test).
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark(theme.colorScheme)
            : AppPalette.light(theme.colorScheme));
  }
}

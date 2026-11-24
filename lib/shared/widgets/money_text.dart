import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/currency_utils.dart';

/// What an amount means, which decides its color and spoken label.
enum MoneyKind { income, expense, transfer, loan, neutral }

extension MoneyKindColor on MoneyKind {
  Color color(BuildContext context) {
    final palette = context.palette;
    return switch (this) {
      MoneyKind.income => palette.income,
      MoneyKind.expense => palette.expense,
      MoneyKind.transfer => palette.transfer,
      MoneyKind.loan => palette.loan,
      MoneyKind.neutral => Theme.of(context).colorScheme.onSurface,
    };
  }

  String get spokenLabel => switch (this) {
        MoneyKind.income => 'Income',
        MoneyKind.expense => 'Expense',
        MoneyKind.transfer => 'Transfer',
        MoneyKind.loan => 'Loan',
        MoneyKind.neutral => '',
      };
}

/// A money amount: tabular figures, colored by [kind], and announced to
/// screen readers with its meaning ("Expense, $14.50").
///
/// [prefix] is prepended to the formatted amount, e.g. '-' or '+'.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.currency = 'USD',
    this.kind = MoneyKind.neutral,
    this.prefix = '',
    this.style,
    this.color,
    this.semanticLabel,
    this.textAlign,
  });

  final double amount;
  final String currency;
  final MoneyKind kind;
  final String prefix;
  final TextStyle? style;

  /// Overrides the color that [kind] would give.
  final Color? color;

  /// Overrides the spoken label (defaults to the kind, e.g. "Expense").
  final String? semanticLabel;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text =
        '$prefix${CurrencyUtils.format(amount, currencyCode: currency)}';
    final base = style ?? Theme.of(context).textTheme.titleSmall!;
    final label = semanticLabel ?? kind.spokenLabel;
    return Semantics(
      label: label.isEmpty ? text : '$label, $text',
      excludeSemantics: true,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base.tabular.copyWith(color: color ?? kind.color(context)),
      ),
    );
  }
}

/// A large amount that counts up to its value, then animates from the old
/// value whenever it changes. Respects the system "remove animations"
/// setting.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(
    this.amount, {
    super.key,
    this.currency = 'USD',
    this.style,
    this.semanticLabel,
  });

  final double amount;
  final String currency;
  final TextStyle? style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final finalText = CurrencyUtils.format(amount, currencyCode: currency);
    return Semantics(
      label: semanticLabel == null ? finalText : '$semanticLabel, $finalText',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: amount),
        duration: reduceMotion ? Duration.zero : Motion.countUp,
        curve: Motion.standard,
        builder: (context, value, _) => Text(
          CurrencyUtils.format(value, currencyCode: currency),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (style ?? Theme.of(context).textTheme.displaySmall!).tabular,
        ),
      ),
    );
  }
}

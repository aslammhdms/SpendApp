import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';

/// Amount display on top, an optional [middle] section (category and
/// details), then a number pad that fills the remaining height.
class AmountInputPad extends StatefulWidget {
  final double initialAmount;
  final String currency;
  final ValueChanged<double> onAmountChanged;

  /// Shown between the amount and the keys.
  final Widget? middle;

  /// Color of the amount; defaults to the surface text color.
  final Color? amountColor;

  const AmountInputPad({
    super.key,
    this.initialAmount = 0,
    this.currency = 'USD',
    required this.onAmountChanged,
    this.middle,
    this.amountColor,
  });

  @override
  State<AmountInputPad> createState() => _AmountInputPadState();
}

class _AmountInputPadState extends State<AmountInputPad> {
  late String _amountString;

  @override
  void initState() {
    super.initState();
    _amountString = widget.initialAmount > 0
        ? widget.initialAmount
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'\.?0+$'), '')
        : '';
  }

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'backspace') {
        if (_amountString.isNotEmpty) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        }
      } else if (key == '.') {
        if (!_amountString.contains('.') && _amountString.isNotEmpty) {
          _amountString += '.';
        }
      } else if (key == 'C') {
        _amountString = '';
      } else {
        // Check decimal places
        if (_amountString.contains('.')) {
          final parts = _amountString.split('.');
          if (parts[1].length >= 2) return;
        }
        // Limit total length
        if (_amountString.replaceAll('.', '').length >= 10) return;
        _amountString += key;
      }
    });

    final amount = double.tryParse(_amountString) ?? 0;
    widget.onAmountChanged(amount);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = double.tryParse(_amountString) ?? 0;
    final formatted =
        CurrencyUtils.format(amount, currencyCode: widget.currency);

    final display = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.sm,
      ),
      child: Semantics(
        liveRegion: true,
        label: 'Amount, $formatted',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: Motion.fast,
                style: text.headlineMedium!.tabular.copyWith(
                  fontSize: 40,
                  height: 1.15,
                  color: _amountString.isEmpty
                      ? scheme.onSurfaceVariant
                      : (widget.amountColor ?? scheme.onSurface),
                ),
                child: Text(formatted),
              ),
            ),
            if (_amountString.isEmpty)
              Text(
                'Enter amount',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.middle == null) {
          return Column(
            children: [
              display,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => _keypad(
                    (c.maxHeight / 4).clamp(Sizes.touchTarget, 64.0),
                  ),
                ),
              ),
            ],
          );
        }
        // Keys get a fixed share of the height; the middle section keeps
        // its natural size (scrolling on very short screens) and the
        // amount is centred in what is left, so there is no dead gap.
        final keyHeight =
            (constraints.maxHeight * 0.4 / 4).clamp(Sizes.touchTarget, 64.0);
        return Column(
          children: [
            Expanded(child: Center(child: display)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.42,
              ),
              child: SingleChildScrollView(child: widget.middle),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(height: keyHeight * 4, child: _keypad(keyHeight)),
          ],
        );
      },
    );
  }

  Widget _keypad(double keyHeight) {
    Widget row(List<String> keys) => SizedBox(
          height: keyHeight,
          child: Row(
            children: [
              for (final k in keys)
                Expanded(child: _buildKey(k, isIcon: k == 'backspace')),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          row(['1', '2', '3']),
          row(['4', '5', '6']),
          row(['7', '8', '9']),
          row(['.', '0', 'backspace']),
        ],
      ),
    );
  }

  Widget _buildKey(String key, {bool isIcon = false}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = isIcon ? 'Delete' : (key == '.' ? 'Decimal point' : key);
    return Padding(
      padding: const EdgeInsets.all(Space.xs / 2),
      child: Semantics(
        button: true,
        label: label,
        hint: isIcon ? 'Long press to clear' : null,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _onKeyPressed(key),
            onLongPress: key == 'backspace' ? () => _onKeyPressed('C') : null,
            child: Center(
              child: isIcon
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 26,
                      color: scheme.onSurfaceVariant,
                    )
                  : Text(
                      key,
                      style: text.headlineSmall?.tabular.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

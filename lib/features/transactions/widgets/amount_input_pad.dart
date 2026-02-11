import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';

class AmountInputPad extends StatefulWidget {
  final double initialAmount;
  final String currency;
  final ValueChanged<double> onAmountChanged;

  const AmountInputPad({
    super.key,
    this.initialAmount = 0,
    this.currency = 'USD',
    required this.onAmountChanged,
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
        ? widget.initialAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')
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
    final amount = double.tryParse(_amountString) ?? 0;

    return Column(
      children: [
        // Display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              Text(
                CurrencyUtils.format(amount, currencyCode: widget.currency),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_amountString.isEmpty)
                Text(
                  'Enter amount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
            ],
          ),
        ),

        // Keypad
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
              _buildKey('.'),
              _buildKey('0'),
              _buildKey('backspace', isIcon: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String key, {bool isIcon = false}) {
    return InkWell(
      onTap: () => _onKeyPressed(key),
      onLongPress: key == 'backspace' ? () => _onKeyPressed('C') : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        child: isIcon
            ? const Icon(
                Icons.backspace_outlined,
                size: 28,
                color: AppColors.textSecondary,
              )
            : Text(
                key,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

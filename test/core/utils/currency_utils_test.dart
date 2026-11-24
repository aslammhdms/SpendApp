import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils', () {
    test('format formats USD correctly', () {
      expect(
        CurrencyUtils.format(1234.56, currencyCode: 'USD'),
        contains('1,234.56'),
      );
    });

    test('format handles zero', () {
      expect(
        CurrencyUtils.format(0, currencyCode: 'USD'),
        contains('0.00'),
      );
    });

    test('format handles negative numbers', () {
      final result = CurrencyUtils.format(-100.50, currencyCode: 'USD');
      expect(result, contains('100.50'));
    });

    test('formatCompact formats large numbers', () {
      expect(
        CurrencyUtils.formatCompact(1500, currencyCode: 'USD'),
        contains('1'),
      );
    });

    test('the riyal is shown by code, with a space', () {
      const space = '\u00A0'; // non-breaking
      expect(CurrencyUtils.format(1250, currencyCode: 'SAR'),
          'SAR${space}1,250.00');
    });

    test('the dirham uses its new sign, before the amount', () {
      expect(CurrencyUtils.dirhamSign.runes.single, 0x20C3);
      expect(CurrencyUtils.format(12.37, currencyCode: 'AED'), '\u20C312.37');
      expect(CurrencyUtils.formatWithSign(-12.37, currencyCode: 'AED'),
          '-\u20C312.37');
    });

    test('outside the app\'s font the dirham falls back to its code', () {
      const space = '\u00A0';
      // Notifications and screen readers cannot show or say the new sign.
      expect(CurrencyUtils.format(12.37, currencyCode: 'AED', plain: true),
          'AED${space}12.37');
      expect(CurrencyUtils.spoken('Net, +\u20C312.37'), 'Net, +AED 12.37');
      // Other currencies are unchanged.
      expect(CurrencyUtils.format(12.37, currencyCode: 'USD', plain: true),
          '\$12.37');
    });

    test('no amount contains right-to-left characters', () {
      final rightToLeft = RegExp('[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
      for (final currency in CurrencyUtils.allCurrencies) {
        final text = CurrencyUtils.format(-1234.5, currencyCode: currency.code);
        expect(rightToLeft.hasMatch(text), isFalse, reason: currency.code);
        expect(text, contains('1,23'), reason: currency.code);
      }
    });

    test('symbol currencies keep their symbol with no space', () {
      expect(CurrencyUtils.format(12.5, currencyCode: 'USD'), r'$12.50');
      expect(CurrencyUtils.format(12.5, currencyCode: 'MYR'), 'RM12.50');
    });

    test('getCurrency returns correct currency info', () {
      expect(CurrencyUtils.getCurrency('USD').symbol, equals('\$'));
      expect(CurrencyUtils.getCurrency('EUR').symbol, equals('\u20AC'));
      expect(CurrencyUtils.getCurrency('GBP').symbol, equals('\u00A3'));
    });

    test('allCurrencies returns list', () {
      final currencies = CurrencyUtils.allCurrencies;
      expect(currencies, isNotEmpty);
      expect(currencies.any((c) => c.code == 'USD'), isTrue);
    });
  });
}

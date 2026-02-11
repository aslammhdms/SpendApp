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

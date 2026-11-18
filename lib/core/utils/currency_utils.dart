import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final Map<String, CurrencyInfo> _currencies = {
    'USD': const CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', decimalDigits: 2),
    'EUR': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', name: 'Euro', decimalDigits: 2),
    'GBP': const CurrencyInfo(code: 'GBP', symbol: '\u00A3', name: 'British Pound', decimalDigits: 2),
    'JPY': const CurrencyInfo(code: 'JPY', symbol: '\u00A5', name: 'Japanese Yen', decimalDigits: 0),
    'CNY': const CurrencyInfo(code: 'CNY', symbol: '\u00A5', name: 'Chinese Yuan', decimalDigits: 2),
    'INR': const CurrencyInfo(code: 'INR', symbol: '\u20B9', name: 'Indian Rupee', decimalDigits: 2),
    'AUD': const CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', decimalDigits: 2),
    'CAD': const CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', decimalDigits: 2),
    'CHF': const CurrencyInfo(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', decimalDigits: 2),
    'KRW': const CurrencyInfo(code: 'KRW', symbol: '\u20A9', name: 'South Korean Won', decimalDigits: 0),
    'SGD': const CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', decimalDigits: 2),
    'HKD': const CurrencyInfo(code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar', decimalDigits: 2),
    'MXN': const CurrencyInfo(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso', decimalDigits: 2),
    'BRL': const CurrencyInfo(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', decimalDigits: 2),
    'RUB': const CurrencyInfo(code: 'RUB', symbol: '\u20BD', name: 'Russian Ruble', decimalDigits: 2),
    'ZAR': const CurrencyInfo(code: 'ZAR', symbol: 'R', name: 'South African Rand', decimalDigits: 2),
    'TRY': const CurrencyInfo(code: 'TRY', symbol: '\u20BA', name: 'Turkish Lira', decimalDigits: 2),
    'THB': const CurrencyInfo(code: 'THB', symbol: '\u0E3F', name: 'Thai Baht', decimalDigits: 2),
    'IDR': const CurrencyInfo(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', decimalDigits: 0),
    'MYR': const CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', decimalDigits: 2),
    'PHP': const CurrencyInfo(code: 'PHP', symbol: '\u20B1', name: 'Philippine Peso', decimalDigits: 2),
    'VND': const CurrencyInfo(code: 'VND', symbol: '\u20AB', name: 'Vietnamese Dong', decimalDigits: 0),
    // Dirham and riyal use their codes. Their own symbols are written right
    // to left, which scrambles the order next to Latin digits ("12.37" then
    // the symbol, with the minus sign on the wrong side).
    'AED': const CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham', decimalDigits: 2),
    'SAR': const CurrencyInfo(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal', decimalDigits: 2),
    'NZD': const CurrencyInfo(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', decimalDigits: 2),
  };

  static List<CurrencyInfo> get allCurrencies => _currencies.values.toList();

  static CurrencyInfo getCurrency(String code) {
    return _currencies[code] ?? _currencies['USD']!;
  }

  /// What goes in front of the number. A currency shown by its code gets a
  /// space after it ("AED 12.37"); a symbol does not ("\$12.37"). The space
  /// is a non-breaking one, so an amount never wraps between the two.
  static String _prefix(CurrencyInfo currency) =>
      currency.symbol == currency.code
          ? '${currency.code}\u00A0'
          : currency.symbol;

  static String format(double amount, {String currencyCode = 'USD', bool showSymbol = true}) {
    final currency = getCurrency(currencyCode);
    final formatter = NumberFormat.currency(
      symbol: showSymbol ? _prefix(currency) : '',
      decimalDigits: currency.decimalDigits,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currencyCode = 'USD'}) {
    final currency = getCurrency(currencyCode);
    final formatter = NumberFormat.compactCurrency(
      symbol: _prefix(currency),
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatWithSign(double amount, {String currencyCode = 'USD'}) {
    final formatted = format(amount.abs(), currencyCode: currencyCode);
    if (amount > 0) {
      return '+$formatted';
    } else if (amount < 0) {
      return '-$formatted';
    }
    return formatted;
  }

  static double parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
  });
}

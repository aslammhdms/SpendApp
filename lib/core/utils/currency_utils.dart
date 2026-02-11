import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final Map<String, CurrencyInfo> _currencies = {
    'USD': CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', decimalDigits: 2),
    'EUR': CurrencyInfo(code: 'EUR', symbol: '\u20AC', name: 'Euro', decimalDigits: 2),
    'GBP': CurrencyInfo(code: 'GBP', symbol: '\u00A3', name: 'British Pound', decimalDigits: 2),
    'JPY': CurrencyInfo(code: 'JPY', symbol: '\u00A5', name: 'Japanese Yen', decimalDigits: 0),
    'CNY': CurrencyInfo(code: 'CNY', symbol: '\u00A5', name: 'Chinese Yuan', decimalDigits: 2),
    'INR': CurrencyInfo(code: 'INR', symbol: '\u20B9', name: 'Indian Rupee', decimalDigits: 2),
    'AUD': CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', decimalDigits: 2),
    'CAD': CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', decimalDigits: 2),
    'CHF': CurrencyInfo(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', decimalDigits: 2),
    'KRW': CurrencyInfo(code: 'KRW', symbol: '\u20A9', name: 'South Korean Won', decimalDigits: 0),
    'SGD': CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', decimalDigits: 2),
    'HKD': CurrencyInfo(code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar', decimalDigits: 2),
    'MXN': CurrencyInfo(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso', decimalDigits: 2),
    'BRL': CurrencyInfo(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', decimalDigits: 2),
    'RUB': CurrencyInfo(code: 'RUB', symbol: '\u20BD', name: 'Russian Ruble', decimalDigits: 2),
    'ZAR': CurrencyInfo(code: 'ZAR', symbol: 'R', name: 'South African Rand', decimalDigits: 2),
    'TRY': CurrencyInfo(code: 'TRY', symbol: '\u20BA', name: 'Turkish Lira', decimalDigits: 2),
    'THB': CurrencyInfo(code: 'THB', symbol: '\u0E3F', name: 'Thai Baht', decimalDigits: 2),
    'IDR': CurrencyInfo(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', decimalDigits: 0),
    'MYR': CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', decimalDigits: 2),
    'PHP': CurrencyInfo(code: 'PHP', symbol: '\u20B1', name: 'Philippine Peso', decimalDigits: 2),
    'VND': CurrencyInfo(code: 'VND', symbol: '\u20AB', name: 'Vietnamese Dong', decimalDigits: 0),
    'AED': CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', decimalDigits: 2),
    'SAR': CurrencyInfo(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal', decimalDigits: 2),
    'NZD': CurrencyInfo(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', decimalDigits: 2),
  };

  static List<CurrencyInfo> get allCurrencies => _currencies.values.toList();

  static CurrencyInfo getCurrency(String code) {
    return _currencies[code] ?? _currencies['USD']!;
  }

  static String format(double amount, {String currencyCode = 'USD', bool showSymbol = true}) {
    final currency = getCurrency(currencyCode);
    final formatter = NumberFormat.currency(
      symbol: showSymbol ? currency.symbol : '',
      decimalDigits: currency.decimalDigits,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currencyCode = 'USD'}) {
    final currency = getCurrency(currencyCode);
    final formatter = NumberFormat.compactCurrency(
      symbol: currency.symbol,
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

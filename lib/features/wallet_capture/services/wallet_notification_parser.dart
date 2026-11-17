/// What a Google Wallet payment notification says, as far as it can be read.
class ParsedPayment {
  const ParsedPayment({
    required this.amount,
    this.currency,
    this.merchant,
    this.cardLast4,
  });

  final double amount;

  /// Currency as written in the notification: a symbol ("$", "€") or a code
  /// ("AED"). Null if none was found.
  final String? currency;

  /// Where the payment was made, if the notification names it.
  final String? merchant;

  /// Last four digits of the card used, if shown.
  final String? cardLast4;
}

/// Reads the amount, merchant and card from the title and text of a Google
/// Wallet notification.
///
/// Google does not document the wording and it varies by country and
/// language, so this looks for the parts it can recognise instead of matching
/// whole sentences: a money amount, a "••1234" card ending, and the name
/// that is left. Notifications without an amount (offers, card set-up) and
/// declined or refunded payments return null.
class WalletNotificationParser {
  const WalletNotificationParser._();

  static const _symbol = r'(?:[A-Z]{1,3})?[$€£¥₹₽₩₺₪₫฿₦₱₴₸₼₾]';
  static const _code =
      'USD|EUR|GBP|INR|AED|SAR|QAR|KWD|BHD|OMR|JOD|EGP|CAD|AUD|NZD|SGD|HKD|'
      'JPY|CNY|KRW|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|TRY|ILS|ZAR|NGN|KES|BRL|'
      'MXN|ARS|CLP|COP|PEN|THB|MYR|IDR|PHP|VND|PKR|BDT|LKR|NPR|RUB|UAH';
  static const _number =
      r'\d{1,3}(?:[.,\u00A0\u202F’]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,3})?';

  /// Currencies written with three decimals, where "1.500" is one and a half.
  static const _threeDecimalCodes = {'KWD', 'BHD', 'OMR', 'JOD', 'TND'};

  /// "$12.50", "US$12.50", "AED 45.00", "12,50 €", "45.00 AED".
  static final _amount = RegExp(
    '(?:(?<pre>$_symbol|\\b(?:$_code))\\s?(?<n1>$_number))'
    '|(?:(?<n2>$_number)\\s?(?<post>$_symbol|(?:$_code)\\b))',
  );

  static final _card = RegExp(r'[•·∙●*]{2,}\s?(\d{4})\b');

  static final _notAPayment = RegExp(
    r"\b(declined|failed|unsuccessful|refund(ed)?|reversed|cancell?ed|couldn['’]t|could not)\b",
    caseSensitive: false,
  );

  /// "... at Blue Bottle with Visa ••1234", read from just after the amount.
  static final _afterAmount = RegExp(
    r'^\s*(?:paid\s+)?(?:at|to|@)\s+(.+)$',
    caseSensitive: false,
  );

  /// "Paid to Blue Bottle" in front of the amount.
  static final _beforeAmount = RegExp(
    r'^(?:you\s+)?(?:paid|payment|sent)\s+(?:to|at)\s+(.+?)[\s:,\-–]*$',
    caseSensitive: false,
  );

  static final _cardPhrase = RegExp(
    r'\s*\b(?:with|using|via|on)\s+(?:your\s+)?'
    r'(?:[^•·∙●*]{0,30}[•·∙●*]{2,}\s?\d{4}'
    r'|(?:visa|mastercard|amex|american express|discover|rupay|maestro|'
    r'debit|credit|card)\b).*$',
    caseSensitive: false,
  );

  static final _generic = RegExp(
    r'^(google\s+(wallet|pay)|payment|purchase|transaction|paid|you paid|'
    r'payment (successful|complete|completed|made)|tap to pay|'
    r'contactless payment)[\s.!:]*$',
    caseSensitive: false,
  );

  static ParsedPayment? parse({required String title, required String text}) {
    final cleanTitle = _clean(title);
    final cleanText = _clean(text);
    final all = '$cleanTitle\n$cleanText';
    if (_notAPayment.hasMatch(all)) return null;

    final titleMatch = _amount.firstMatch(cleanTitle);
    final match = titleMatch ?? _amount.firstMatch(cleanText);
    if (match == null) return null;

    final currency = match.namedGroup('pre') ?? match.namedGroup('post');
    final amount = _toDouble(
      match.namedGroup('n1') ?? match.namedGroup('n2')!,
      threeDecimals: _threeDecimalCodes.contains(currency),
    );
    if (amount == null || amount <= 0) return null;

    final amountInTitle = titleMatch != null;
    return ParsedPayment(
      amount: amount,
      currency: currency,
      merchant: _merchant(
        withAmount: amountInTitle ? cleanTitle : cleanText,
        other: amountInTitle ? cleanText : cleanTitle,
        match: match,
      ),
      cardLast4: _card.firstMatch(all)?.group(1),
    );
  }

  static String? _merchant({
    required String withAmount,
    required String other,
    required RegExpMatch match,
  }) {
    // "You paid $5 at Blue Bottle with Visa ••1234"
    final after = _afterAmount.firstMatch(withAmount.substring(match.end));
    // "Paid to Blue Bottle: ₹250"
    final before =
        _beforeAmount.firstMatch(withAmount.substring(0, match.start));
    return _tidy(after?.group(1)) ??
        _tidy(before?.group(1)) ??
        // The merchant is the other field: title "Blue Bottle",
        // text "$5.40 with Visa ••1234" (or the other way round).
        _tidy(other) ??
        // Everything is in one field: "Blue Bottle $5.40".
        _tidy(withAmount);
  }

  /// Strips amounts, card details and filler from a candidate merchant name.
  static String? _tidy(String? value) {
    if (value == null) return null;
    var name = value
        .replaceAll(_cardPhrase, '')
        .replaceAll(_amount, '')
        .replaceAll(_card, '')
        .replaceAll(
            RegExp(r'^(you\s+)?(paid|payment|purchase)\b[\s:,\-–]*(at|to)?\s*',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:,\-–•]+|[\s:,\-–•.]+$'), '');
    if (name.isEmpty || _generic.hasMatch(name)) return null;
    // A name needs at least one letter.
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) return null;
    if (name.length > 60) name = name.substring(0, 60).trimRight();
    return name;
  }

  static String _clean(String value) => value
      // Direction marks some locales wrap around amounts.
      .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '')
      .trim();

  /// Parses "1,234.56", "1.234,56", "5,40", "1 234,56" and "250".
  static double? _toDouble(String raw, {required bool threeDecimals}) {
    var s = raw.replaceAll(RegExp(r'[\s\u00A0\u202F’]'), '');
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      // With both, the later one is the decimal separator.
      final decimal = lastComma > lastDot ? ',' : '.';
      final group = decimal == ',' ? '.' : ',';
      s = s.replaceAll(group, '').replaceAll(decimal, '.');
    } else if (lastComma >= 0 || lastDot >= 0) {
      final sep = lastComma >= 0 ? ',' : '.';
      final digitsAfter = s.length - s.lastIndexOf(sep) - 1;
      // "1,234" is a thousands separator; "5,40" and "5.4" are decimals.
      final isGrouping = digitsAfter == 3 && !threeDecimals;
      s = isGrouping ? s.replaceAll(sep, '') : s.replaceAll(sep, '.');
    }
    return double.tryParse(s);
  }
}

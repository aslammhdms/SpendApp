import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/wallet_capture/services/wallet_notification_parser.dart';

ParsedPayment? parse(String title, String text) =>
    WalletNotificationParser.parse(title: title, text: text);

void main() {
  group('merchant in the title, amount in the text', () {
    test('reads amount, merchant and card', () {
      final p = parse('Blue Bottle Coffee', r'$5.40 with Visa ••1234')!;
      expect(p.amount, 5.40);
      expect(p.currency, r'$');
      expect(p.merchant, 'Blue Bottle Coffee');
      expect(p.cardLast4, '1234');
    });

    test('keeps "to" and "with" that belong to the merchant name', () {
      expect(parse('Coffee to Go', r'$3.00 with Visa ••1234')!.merchant,
          'Coffee to Go');
      expect(parse('Tea with Milk', r'$4.00 with Mastercard •••• 9876')!.merchant,
          'Tea with Milk');
    });

    test('reads the card after four bullets and a space', () {
      expect(parse('Shop', r'$4.00 with Mastercard •••• 9876')!.cardLast4,
          '9876');
    });
  });

  group('amount in the title', () {
    test('takes the merchant from the text', () {
      final p = parse(r'$12.00', 'Whole Foods Market')!;
      expect(p.amount, 12.0);
      expect(p.merchant, 'Whole Foods Market');
    });

    test('drops the card phrase from the merchant', () {
      final p = parse('€8,50', 'Bäckerei Müller with Mastercard ••4321')!;
      expect(p.amount, 8.5);
      expect(p.merchant, 'Bäckerei Müller');
      expect(p.cardLast4, '4321');
    });
  });

  group('everything in one sentence', () {
    test('"You paid X at Y with card"', () {
      final p = parse('Google Wallet',
          r'You paid $23.10 at Trader Joe' "'" r's with Visa ••1234.')!;
      expect(p.amount, 23.10);
      expect(p.merchant, "Trader Joe's");
      expect(p.cardLast4, '1234');
    });

    test('"Paid to Y" before the amount', () {
      final p = parse('Payment successful', 'Paid to Sharma Stores ₹250.00')!;
      expect(p.amount, 250.0);
      expect(p.currency, '₹');
      expect(p.merchant, 'Sharma Stores');
    });

    test('generic titles are not taken as the merchant', () {
      final p = parse('Google Wallet', r'$9.99')!;
      expect(p.amount, 9.99);
      expect(p.merchant, isNull);
    });
  });

  group('amount formats', () {
    test('currency code before or after', () {
      expect(parse('Carrefour', 'AED 45.00 with Visa ••1111')!.amount, 45.0);
      expect(parse('Carrefour', 'AED 45.00 with Visa ••1111')!.currency, 'AED');
      expect(parse('Lidl', '12,50 EUR')!.amount, 12.5);
      expect(parse('Lidl', '12,50 EUR')!.currency, 'EUR');
    });

    test('symbol after the number', () {
      final p = parse('Lidl', '12,50 € mit Mastercard ••4321')!;
      expect(p.amount, 12.5);
      expect(p.currency, '€');
    });

    test('thousands and decimal separators', () {
      expect(parse('Apple Store', r'$1,234.56')!.amount, 1234.56);
      expect(parse('MediaMarkt', '1.234,56 €')!.amount, 1234.56);
      expect(parse('IKEA', '1\u00A0234,56 €')!.amount, 1234.56);
      expect(parse('Croma', '₹1,500')!.amount, 1500.0);
      expect(parse('Kiosk', '₹250')!.amount, 250.0);
    });

    test('three-decimal currencies keep their decimals', () {
      expect(parse('Lulu', 'KWD 1.500 with Visa ••1111')!.amount, 1.5);
    });

    test('prefixed dollar symbols', () {
      final p = parse('Tim Hortons', r'CA$4.25 with Visa ••1234')!;
      expect(p.amount, 4.25);
      expect(p.currency, r'CA$');
    });

    test('ignores text direction marks around the amount', () {
      expect(parse('Shop', '\u200E\$7.00\u200E with Visa ••1234')!.amount, 7.0);
    });
  });

  group('not a payment', () {
    test('notifications without an amount', () {
      expect(parse('Your card is ready', 'Visa ••1234 was added to Wallet'),
          isNull);
      expect(parse('Boarding pass', 'Flight AB 1234 boards at 10:40'), isNull);
    });

    test('declined and refunded payments', () {
      expect(parse('Blue Bottle', r'$5.40 payment declined'), isNull);
      expect(parse('Amazon', r'Refund of $20.00 to Visa ••1234'), isNull);
    });

    test('zero amounts', () {
      expect(parse('Transit', r'$0.00 with Visa ••1234'), isNull);
    });
  });

  group('amounts that only look like the payment', () {
    test('an amount in the merchant name does not replace the paid amount',
        () {
      final payment = parse('USD 1 SHOP', r'$54.20 with Visa ••1234');
      expect(payment?.amount, 54.20);
    });

    test('an absurdly long number is not a payment', () {
      final digits = '9' * 400;
      expect(parse('Shop', 'USD $digits with Visa ••1234'), isNull);
    });

    test('cashback notices are not payments', () {
      expect(parse('Google Wallet', r'You earned $2.00 cashback'), isNull);
    });
  });
}

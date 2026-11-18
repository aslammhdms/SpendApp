import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/constants/category_defaults.dart';
import 'package:spendsheet/data/models/category.dart';
import 'package:spendsheet/features/wallet_capture/services/merchant_categorizer.dart';

Category _category(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: '📌',
      color: 0xFF6366F1,
      sortOrder: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('guessing from the name', () {
    const cases = {
      // The first real notification the feature was tried with.
      'LIFECARE HOSPITAL LLC-': 'cat_health',
      'Life Pharmacy 214': 'cat_health',
      'ASTER CLINIC AL QUSAIS': 'cat_health',
      'CARREFOUR HYPERMARKET': 'cat_grocery',
      'Lulu Express': 'cat_grocery',
      'AL MAYA SUPERMARKET LLC': 'cat_grocery',
      'Whole Foods Market': 'cat_grocery',
      'Blue Bottle Coffee': 'cat_food',
      "McDonald's Marina": 'cat_food',
      'AL SAFADI RESTAURANT': 'cat_food',
      'TALABAT': 'cat_food',
      'ADNOC 437': 'cat_transport',
      'ENOC SITE 1046': 'cat_transport',
      'Careem Ride': 'cat_transport',
      'RTA PARKING': 'cat_transport',
      'AMAZON.AE': 'cat_shopping',
      'H&M Dubai Mall': 'cat_shopping',
      'IKEA Festival City': 'cat_shopping',
      'NETFLIX.COM': 'cat_subscriptions',
      'Amazon Prime': 'cat_subscriptions',
      'VOX CINEMAS': 'cat_entertainment',
      'DEWA': 'cat_bills',
      'du Telecom': 'cat_bills',
      'GEMS WELLINGTON SCHOOL': 'cat_education',
      'TIPS AND TOES NAILS SPA': 'cat_personal',
      'Fitness First': 'cat_fitness',
      'ORIENT INSURANCE PJSC': 'cat_insurance',
      'ROVE HOTEL': 'cat_travel',
      'Air Arabia': 'cat_travel',
      'PET ZONE': 'cat_pets',
    };
    for (final MapEntry(key: merchant, value: categoryId) in cases.entries) {
      test('$merchant is $categoryId', () {
        expect(MerchantCategorizer.builtInIdFor(merchant), categoryId);
      });
    }

    test('gives no guess for a name with nothing to go on', () {
      for (final merchant in [
        'AL FUTTAIM LLC',
        'XYZ TRADING',
        'M S ENTERPRISES',
        'Rahul',
        '',
      ]) {
        expect(MerchantCategorizer.builtInIdFor(merchant), isNull,
            reason: merchant);
      }
    });

    test('matches whole words only', () {
      // "marketing" is not "market", "duty" is not "du", "malls" is unknown.
      expect(MerchantCategorizer.builtInIdFor('ACME MARKETING'), isNull);
      expect(MerchantCategorizer.builtInIdFor('DUTY CALLS LLC'), isNull);
      expect(MerchantCategorizer.builtInIdFor('SPARE PARTS'), isNull);
    });

    test('the more specific words win', () {
      expect(MerchantCategorizer.builtInIdFor('PET PHARMACY'), 'cat_health');
      expect(MerchantCategorizer.builtInIdFor('MALL PARKING'),
          'cat_transport');
    });

    test('every keyword belongs to a built-in expense category', () {
      final ids = {
        for (final d in CategoryDefaults.expenseCategories) d.id,
      };
      expect(ids, containsAll(MerchantCategorizer.keywords.keys));
    });

    test('no word is listed under two categories', () {
      final seen = <String, String>{};
      for (final entry in MerchantCategorizer.keywords.entries) {
        for (final keyword in entry.value) {
          expect(seen[keyword], isNull,
              reason: '"$keyword" is in ${seen[keyword]} and ${entry.key}');
          seen[keyword] = entry.key;
        }
      }
    });
  });

  group('finding the category in the list', () {
    test('uses the built-in when it is there', () {
      final categories = [
        _category('cat_food', 'Food & Dining'),
        _category('cat_health', 'Healthcare'),
      ];

      expect(
        MerchantCategorizer.categoryIdFor('LIFECARE HOSPITAL LLC-', categories),
        'cat_health',
      );
    });

    test('uses the same-named category of an older spreadsheet', () {
      final categories = [
        _category('a1b2', 'Food & Dining'),
        _category('c3d4', 'healthcare '),
      ];

      expect(
        MerchantCategorizer.categoryIdFor('LIFECARE HOSPITAL LLC-', categories),
        'c3d4',
      );
    });

    test('gives nothing when that category was deleted or renamed', () {
      final categories = [_category('cat_food', 'Food & Dining')];

      expect(
        MerchantCategorizer.categoryIdFor('LIFECARE HOSPITAL LLC-', categories),
        isNull,
      );
    });
  });

  group('recognising the same merchant', () {
    test('drops company words and branch numbers', () {
      expect(MerchantCategorizer.key('LIFECARE HOSPITAL LLC-'),
          'lifecare hospital');
      expect(MerchantCategorizer.key('Lifecare Hospital Br 2'),
          'lifecare hospital');
      expect(MerchantCategorizer.key('ADNOC 437'), 'adnoc');
    });

    test('keeps a name made only of such words', () {
      expect(MerchantCategorizer.key('The Trading Co'), 'the trading co');
    });

    test('one name may be the start of the other', () {
      expect(
        MerchantCategorizer.sameMerchant('starbucks', 'starbucks dubai mall'),
        isTrue,
      );
      expect(
        MerchantCategorizer.sameMerchant(
            'lifecare hospital musaffah', 'lifecare hospital'),
        isTrue,
      );
    });

    test('different places are not the same', () {
      expect(
        MerchantCategorizer.sameMerchant('lifecare hospital', 'lifeline hospital'),
        isFalse,
      );
      expect(
        MerchantCategorizer.sameMerchant('al maya', 'al safadi restaurant'),
        isFalse,
      );
    });

    test('one short word is not enough', () {
      expect(MerchantCategorizer.sameMerchant('al', 'al safadi'), isFalse);
      expect(MerchantCategorizer.sameMerchant('zara', 'zara home'), isFalse);
    });
  });
}

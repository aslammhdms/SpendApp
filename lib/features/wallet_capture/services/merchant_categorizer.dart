import '../../../core/constants/category_defaults.dart';
import '../../../data/models/category.dart';

/// Guesses an expense category from a merchant's name, on the device.
///
/// A Google Wallet notification says where the money went but not what
/// kind of place it is, so the name is all there is to go on. Words in it
/// are matched against lists of telling words ("HOSPITAL", "SUPERMARKET",
/// "ADNOC"). It is a guess for the person to confirm, and it returns
/// nothing rather than a weak guess.
abstract final class MerchantCategorizer {
  /// Telling words per built-in category ID. A phrase with spaces must
  /// appear as those whole words in that order. Words that fit many kinds
  /// of business ("store", "home", "service") are left out on purpose.
  static const Map<String, List<String>> keywords = {
    'cat_health': [
      'hospital', 'clinic', 'clinics', 'pharmacy', 'pharmacies', 'pharma',
      'medical', 'medicare', 'medcare', 'mediclinic', 'dental', 'dentist',
      'optical', 'opticals', 'optician', 'opticians', 'laboratory', 'lab',
      'diagnostic', 'diagnostics', 'healthcare', 'polyclinic', 'chemist',
      'drugstore', 'physiotherapy', 'aster', 'nmc', 'boots',
    ],
    'cat_grocery': [
      'supermarket', 'supermarkets', 'hypermarket', 'hypermarkets', 'grocery',
      'groceries', 'minimart', 'mart', 'baqala', 'market', 'carrefour',
      'lulu', 'spinneys', 'waitrose', 'choithrams', 'nesto', 'union coop',
      'coop', 'viva', 'kibsons', 'walmart', 'tesco', 'aldi', 'lidl',
      'whole foods', 'kroger', 'costco', 'safeway', 'trader joe',
      'bigbasket', 'big basket', 'dmart', 'geant', 'grandiose', 'zoom market',
    ],
    'cat_food': [
      'restaurant', 'restaurants', 'cafe', 'cafeteria', 'coffee', 'bakery',
      'bakeries', 'diner', 'bistro', 'eatery', 'kitchen', 'grill', 'grills',
      'pizza', 'pizzeria', 'burger', 'burgers', 'shawarma', 'biryani',
      'sushi', 'bbq', 'karak', 'sweets', 'juice', 'starbucks', 'costa',
      'tim hortons', 'mcdonalds', 'mcdonald', 'kfc', 'subway', 'dominos',
      'hardees', 'nandos', 'dunkin', 'baskin', 'talabat', 'deliveroo',
      'zomato', 'swiggy', 'uber eats', 'doordash', 'noon food', 'food court',
      'roastery', 'tea house', 'ice cream',
    ],
    'cat_transport': [
      'petrol', 'fuel', 'filling station', 'gas station', 'service station',
      'adnoc', 'enoc', 'eppco', 'emarat', 'shell', 'uber', 'careem', 'taxi',
      'rta', 'nol', 'salik', 'darb', 'mawaqif', 'parking', 'metro', 'toll',
      'bolt', 'lyft', 'ola', 'hala', 'car wash', 'carwash', 'tyre', 'tyres',
      'tires', 'garage', 'railway', 'railways', 'transport',
    ],
    'cat_shopping': [
      'mall', 'amazon', 'noon', 'namshi', 'shein', 'ikea', 'zara', 'h m',
      'nike', 'adidas', 'centrepoint', 'max fashion', 'splash', 'lifestyle',
      'home centre', 'sharaf dg', 'jumbo electronics', 'emax', 'electronics',
      'fashion', 'boutique', 'flipkart', 'myntra', 'ebay', 'aliexpress',
      'temu', 'decathlon', 'department store', 'apparel', 'garments',
      'footwear', 'jewellery', 'jewelry',
    ],
    'cat_subscriptions': [
      'netflix', 'spotify', 'youtube', 'apple com bill', 'itunes',
      'google one', 'icloud', 'disney', 'prime video', 'amazon prime', 'osn',
      'shahid', 'anghami', 'adobe', 'microsoft', 'openai', 'chatgpt',
      'subscription', 'patreon', 'google play',
    ],
    'cat_entertainment': [
      'cinema', 'cinemas', 'vox', 'reel', 'novo', 'theatre', 'theater',
      'playstation', 'steam', 'bowling', 'museum', 'concert', 'amusement',
      'arcade', 'waterpark', 'theme park', 'ticketmaster', 'platinumlist',
    ],
    'cat_bills': [
      'dewa', 'sewa', 'addc', 'aadc', 'fewa', 'etihad we', 'etisalat', 'du',
      'virgin mobile', 'telecom', 'electricity', 'broadband', 'recharge',
      'utility', 'utilities', 'empower', 'tabreed', 'airtel', 'jio',
      'vodafone', 'verizon',
    ],
    'cat_education': [
      'school', 'schools', 'university', 'college', 'academy', 'institute',
      'tuition', 'nursery', 'kindergarten', 'udemy', 'coursera', 'bookstore',
      'bookshop', 'stationery', 'library',
    ],
    'cat_personal': [
      'salon', 'saloon', 'barber', 'barbershop', 'spa', 'beauty', 'nails',
      'cosmetics', 'sephora', 'perfume', 'perfumes', 'laundry', 'dry clean',
      'dry cleaning', 'dry cleaners',
    ],
    'cat_fitness': [
      'gym', 'fitness', 'yoga', 'crossfit', 'pilates', 'sports club',
    ],
    'cat_home': [
      'furniture', 'hardware', 'plumbing', 'homeware', 'home decor',
    ],
    'cat_insurance': ['insurance', 'takaful', 'assurance'],
    'cat_travel': [
      'airline', 'airlines', 'airways', 'etihad airways', 'flydubai',
      'air arabia', 'indigo', 'hotel', 'hotels', 'resort', 'resorts',
      'booking com', 'airbnb', 'expedia', 'makemytrip', 'travel', 'travels',
      'tours', 'airport', 'duty free',
    ],
    'cat_gifts': ['gift', 'gifts', 'florist', 'flowers'],
    'cat_pets': ['pet', 'pets', 'vet', 'veterinary'],
    'cat_kids': ['toys', 'babyshop', 'mothercare', 'kids'],
    'cat_taxes': ['tax', 'taxes'],
  };

  /// Words that say what kind of company it is, not which one.
  static const _legalWords = {
    'llc', 'l', 'c', 'ltd', 'limited', 'inc', 'co', 'corp', 'company', 'fz',
    'fze', 'fzc', 'fzco', 'pjsc', 'psc', 'est', 'establishment', 'br',
    'branch', 'tr', 'trading', 'the', 'sole', 'proprietorship', 'dmcc',
    'wll', 'llp', 'pvt', 'plc', 'gmbh',
  };

  /// The merchant name as lower-case words: "LIFECARE HOSPITAL LLC-" gives
  /// `[lifecare, hospital, llc]`.
  static List<String> words(String merchant) => merchant
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// A key that is the same for different spellings of one merchant:
  /// company words and branch numbers are dropped, so "LIFECARE HOSPITAL
  /// LLC-" and "Lifecare Hospital Br 2" both give "lifecare hospital".
  static String key(String merchant) {
    final all = words(merchant);
    final kept = all
        .where((w) => !_legalWords.contains(w) && int.tryParse(w) == null)
        .toList();
    return (kept.isEmpty ? all : kept).join(' ');
  }

  /// The built-in category ID whose words best fit [merchant], or null.
  /// The longest matching word or phrase wins, so "life pharmacy" is
  /// healthcare and "amazon prime" is a subscription, not shopping.
  static String? builtInIdFor(String merchant) {
    final text = ' ${words(merchant).join(' ')} ';
    String? best;
    var bestLength = 0;
    for (final entry in keywords.entries) {
      for (final keyword in entry.value) {
        if (keyword.length > bestLength && text.contains(' $keyword ')) {
          best = entry.key;
          bestLength = keyword.length;
        }
      }
    }
    return best;
  }

  /// The ID of the category in [categories] that fits [merchant], or null.
  ///
  /// The guess is a built-in category. A spreadsheet made by an older
  /// version holds the built-ins under other IDs, so if the ID is not in
  /// [categories] the category with the built-in's name is used instead.
  static String? categoryIdFor(String merchant, List<Category> categories) {
    final builtInId = builtInIdFor(merchant);
    if (builtInId == null) return null;
    for (final c in categories) {
      if (c.id == builtInId) return c.id;
    }
    final name = CategoryDefaults.expenseCategories
        .firstWhere((d) => d.id == builtInId)
        .name
        .toLowerCase();
    for (final c in categories) {
      if (c.name.trim().toLowerCase() == name) return c.id;
    }
    return null;
  }

  /// Whether two merchant keys are the same place under slightly different
  /// names: one is the start of the other ("starbucks" and "starbucks dubai
  /// mall"). A single short word is not enough to go on.
  static bool sameMerchant(String keyA, String keyB) {
    if (keyA == keyB) return true;
    final a = keyA.split(' '), b = keyB.split(' ');
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    for (var i = 0; i < shorter.length; i++) {
      if (shorter[i] != longer[i]) return false;
    }
    return shorter.length >= 2 || shorter.first.length >= 5;
  }
}

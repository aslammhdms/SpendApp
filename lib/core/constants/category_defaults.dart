import 'package:material_ui/material_ui.dart';

class CategoryDefaults {
  CategoryDefaults._();

  static const List<DefaultCategory> expenseCategories = [
    DefaultCategory(
      id: 'cat_food',
      name: 'Food & Dining',
      icon: '🍔',
      color: 0xFFFF6B6B,
    ),
    DefaultCategory(
      id: 'cat_grocery',
      name: 'Groceries',
      icon: '🛒',
      color: 0xFF4ECDC4,
    ),
    DefaultCategory(
      id: 'cat_transport',
      name: 'Transportation',
      icon: '🚗',
      color: 0xFF45B7D1,
    ),
    DefaultCategory(
      id: 'cat_shopping',
      name: 'Shopping',
      icon: '🛍️',
      color: 0xFFFF8ED4,
    ),
    DefaultCategory(
      id: 'cat_entertainment',
      name: 'Entertainment',
      icon: '🎬',
      color: 0xFFFFBE0B,
    ),
    DefaultCategory(
      id: 'cat_bills',
      name: 'Bills & Utilities',
      icon: '📱',
      color: 0xFF7B68EE,
    ),
    DefaultCategory(
      id: 'cat_health',
      name: 'Healthcare',
      icon: '🏥',
      color: 0xFFFF6F61,
    ),
    DefaultCategory(
      id: 'cat_education',
      name: 'Education',
      icon: '📚',
      color: 0xFF00CED1,
    ),
    DefaultCategory(
      id: 'cat_personal',
      name: 'Personal Care',
      icon: '💅',
      color: 0xFFDDA0DD,
    ),
    DefaultCategory(
      id: 'cat_fitness',
      name: 'Fitness',
      icon: '🏋️',
      color: 0xFF98D8C8,
    ),
    DefaultCategory(
      id: 'cat_home',
      name: 'Home',
      icon: '🏠',
      color: 0xFFD4A574,
    ),
    DefaultCategory(
      id: 'cat_insurance',
      name: 'Insurance',
      icon: '🛡️',
      color: 0xFF778899,
    ),
    DefaultCategory(
      id: 'cat_travel',
      name: 'Travel',
      icon: '✈️',
      color: 0xFF87CEEB,
    ),
    DefaultCategory(
      id: 'cat_gifts',
      name: 'Gifts',
      icon: '🎁',
      color: 0xFFFF69B4,
    ),
    DefaultCategory(
      id: 'cat_subscriptions',
      name: 'Subscriptions',
      icon: '📺',
      color: 0xFF9370DB,
    ),
    DefaultCategory(
      id: 'cat_pets',
      name: 'Pets',
      icon: '🐾',
      color: 0xFFA0522D,
    ),
    DefaultCategory(
      id: 'cat_kids',
      name: 'Kids',
      icon: '👶',
      color: 0xFFFFB6C1,
    ),
    DefaultCategory(
      id: 'cat_taxes',
      name: 'Taxes',
      icon: '🧾',
      color: 0xFF696969,
    ),
    DefaultCategory(
      id: 'cat_investments',
      name: 'Investments',
      icon: '📈',
      color: 0xFF228B22,
    ),
    DefaultCategory(
      id: 'cat_other_expense',
      name: 'Other Expense',
      icon: '💸',
      color: 0xFF808080,
    ),
  ];

  static const List<DefaultCategory> incomeCategories = [
    DefaultCategory(
      id: 'cat_salary',
      name: 'Salary',
      icon: '💰',
      color: 0xFF2ECC71,
    ),
    DefaultCategory(
      id: 'cat_freelance',
      name: 'Freelance',
      icon: '💻',
      color: 0xFF3498DB,
    ),
    DefaultCategory(
      id: 'cat_business',
      name: 'Business',
      icon: '🏢',
      color: 0xFF9B59B6,
    ),
    DefaultCategory(
      id: 'cat_invest_income',
      name: 'Investments',
      icon: '📊',
      color: 0xFF1ABC9C,
    ),
    DefaultCategory(
      id: 'cat_rental',
      name: 'Rental Income',
      icon: '🏘️',
      color: 0xFFE67E22,
    ),
    DefaultCategory(
      id: 'cat_gifts_received',
      name: 'Gifts Received',
      icon: '🎀',
      color: 0xFFE91E63,
    ),
    DefaultCategory(
      id: 'cat_refunds',
      name: 'Refunds',
      icon: '↩️',
      color: 0xFF00BCD4,
    ),
    DefaultCategory(
      id: 'cat_other_income',
      name: 'Other Income',
      icon: '💵',
      color: 0xFF607D8B,
    ),
  ];

  static const List<DefaultAccount> defaultAccounts = [
    DefaultAccount(
      id: 'acc_cash',
      name: 'Cash',
      type: 'cash',
      icon: '💵',
      color: 0xFF4CAF50,
    ),
    DefaultAccount(
      id: 'acc_bank',
      name: 'Bank Account',
      type: 'bank',
      icon: '🏦',
      color: 0xFF2196F3,
    ),
    DefaultAccount(
      id: 'acc_credit',
      name: 'Credit Card',
      type: 'credit',
      icon: '💳',
      color: 0xFFF44336,
    ),
  ];

  /// Colors offered when creating a category or account. These are stored
  /// with the user's data, so they are fixed values, not theme colors.
  static const List<Color> pickerColors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
  ];

  static const List<String> availableIcons = [
    '🍔', '🛒', '🚗', '🛍️', '🎬', '📱', '🏥', '📚', '💅', '🏋️',
    '🏠', '🛡️', '✈️', '🎁', '📺', '🐾', '👶', '🧾', '📈', '💸',
    '💰', '💻', '🏢', '📊', '🏘️', '🎀', '↩️', '💵', '💳', '🏦',
    '🎮', '🎵', '☕', '🍕', '🍺', '⛽', '🚌', '🚇', '🎓', '💊',
    '🔧', '🎨', '📷', '🎤', '⚽', '🏀', '🎾', '🏊', '🚴', '🧘',
  ];
}

class DefaultCategory {
  /// Fixed ID shared by the local database and new spreadsheets, so both
  /// sides refer to the same built-in category.
  final String id;
  final String name;
  final String icon;
  final int color;

  const DefaultCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  Color get colorValue => Color(color);
}

class DefaultAccount {
  /// Fixed ID shared by the local database and new spreadsheets, so both
  /// sides refer to the same built-in account.
  final String id;
  final String name;
  final String type;
  final String icon;
  final int color;

  const DefaultAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  Color get colorValue => Color(color);
}

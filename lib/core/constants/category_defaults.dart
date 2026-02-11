import 'package:flutter/material.dart';

class CategoryDefaults {
  CategoryDefaults._();

  static const List<DefaultCategory> expenseCategories = [
    DefaultCategory(
      name: 'Food & Dining',
      icon: '🍔',
      color: 0xFFFF6B6B,
    ),
    DefaultCategory(
      name: 'Groceries',
      icon: '🛒',
      color: 0xFF4ECDC4,
    ),
    DefaultCategory(
      name: 'Transportation',
      icon: '🚗',
      color: 0xFF45B7D1,
    ),
    DefaultCategory(
      name: 'Shopping',
      icon: '🛍️',
      color: 0xFFFF8ED4,
    ),
    DefaultCategory(
      name: 'Entertainment',
      icon: '🎬',
      color: 0xFFFFBE0B,
    ),
    DefaultCategory(
      name: 'Bills & Utilities',
      icon: '📱',
      color: 0xFF7B68EE,
    ),
    DefaultCategory(
      name: 'Healthcare',
      icon: '🏥',
      color: 0xFFFF6F61,
    ),
    DefaultCategory(
      name: 'Education',
      icon: '📚',
      color: 0xFF00CED1,
    ),
    DefaultCategory(
      name: 'Personal Care',
      icon: '💅',
      color: 0xFFDDA0DD,
    ),
    DefaultCategory(
      name: 'Fitness',
      icon: '🏋️',
      color: 0xFF98D8C8,
    ),
    DefaultCategory(
      name: 'Home',
      icon: '🏠',
      color: 0xFFD4A574,
    ),
    DefaultCategory(
      name: 'Insurance',
      icon: '🛡️',
      color: 0xFF778899,
    ),
    DefaultCategory(
      name: 'Travel',
      icon: '✈️',
      color: 0xFF87CEEB,
    ),
    DefaultCategory(
      name: 'Gifts',
      icon: '🎁',
      color: 0xFFFF69B4,
    ),
    DefaultCategory(
      name: 'Subscriptions',
      icon: '📺',
      color: 0xFF9370DB,
    ),
    DefaultCategory(
      name: 'Pets',
      icon: '🐾',
      color: 0xFFA0522D,
    ),
    DefaultCategory(
      name: 'Kids',
      icon: '👶',
      color: 0xFFFFB6C1,
    ),
    DefaultCategory(
      name: 'Taxes',
      icon: '🧾',
      color: 0xFF696969,
    ),
    DefaultCategory(
      name: 'Investments',
      icon: '📈',
      color: 0xFF228B22,
    ),
    DefaultCategory(
      name: 'Other Expense',
      icon: '💸',
      color: 0xFF808080,
    ),
  ];

  static const List<DefaultCategory> incomeCategories = [
    DefaultCategory(
      name: 'Salary',
      icon: '💰',
      color: 0xFF2ECC71,
    ),
    DefaultCategory(
      name: 'Freelance',
      icon: '💻',
      color: 0xFF3498DB,
    ),
    DefaultCategory(
      name: 'Business',
      icon: '🏢',
      color: 0xFF9B59B6,
    ),
    DefaultCategory(
      name: 'Investments',
      icon: '📊',
      color: 0xFF1ABC9C,
    ),
    DefaultCategory(
      name: 'Rental Income',
      icon: '🏘️',
      color: 0xFFE67E22,
    ),
    DefaultCategory(
      name: 'Gifts Received',
      icon: '🎀',
      color: 0xFFE91E63,
    ),
    DefaultCategory(
      name: 'Refunds',
      icon: '↩️',
      color: 0xFF00BCD4,
    ),
    DefaultCategory(
      name: 'Other Income',
      icon: '💵',
      color: 0xFF607D8B,
    ),
  ];

  static const List<DefaultAccount> defaultAccounts = [
    DefaultAccount(
      name: 'Cash',
      type: 'cash',
      icon: '💵',
      color: 0xFF4CAF50,
    ),
    DefaultAccount(
      name: 'Bank Account',
      type: 'bank',
      icon: '🏦',
      color: 0xFF2196F3,
    ),
    DefaultAccount(
      name: 'Credit Card',
      type: 'credit',
      icon: '💳',
      color: 0xFFF44336,
    ),
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
  final String name;
  final String icon;
  final int color;

  const DefaultCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  Color get colorValue => Color(color);
}

class DefaultAccount {
  final String name;
  final String type;
  final String icon;
  final int color;

  const DefaultAccount({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  Color get colorValue => Color(color);
}

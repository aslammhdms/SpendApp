import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

enum CategoryType {
  @JsonValue('expense')
  expense,
  @JsonValue('income')
  income,
}

@freezed
class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String name,
    required CategoryType type,
    required String icon,
    required int color,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isExpense => type == CategoryType.expense;
  bool get isIncome => type == CategoryType.income;

  Color get colorValue => Color(color);

  Category copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Category fromSheetRow(List<dynamic> row) {
    return Category(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      type: CategoryType.values.firstWhere(
        (e) => e.name == row[2]?.toString(),
        orElse: () => CategoryType.expense,
      ),
      icon: row[3]?.toString() ?? '',
      color: int.tryParse(row[4]?.toString() ?? '0') ?? 0xFF808080,
      sortOrder: int.tryParse(row[5]?.toString() ?? '0') ?? 0,
      createdAt: DateTime.parse(row[6]?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(row[7]?.toString() ?? DateTime.now().toIso8601String()),
      deletedAt: row[8]?.toString().isNotEmpty == true
          ? DateTime.parse(row[8].toString())
          : null,
    );
  }
}

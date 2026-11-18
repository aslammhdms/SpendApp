import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

enum AccountType {
  @JsonValue('cash')
  cash,
  @JsonValue('bank')
  bank,
  @JsonValue('credit')
  credit,
  @JsonValue('savings')
  savings,
  @JsonValue('investment')
  investment,
  @JsonValue('wallet')
  wallet,
  @JsonValue('other')
  other,
}

@freezed
abstract class Account with _$Account {
  const Account._();

  const factory Account({
    required String id,
    required String name,
    required AccountType type,
    required double initialBalance,
    required String currency,
    required String icon,
    required int color,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    @Default(0) double currentBalance,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isCredit => type == AccountType.credit;

  Color get colorValue => Color(color);

  Account copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'initial_balance': initialBalance,
      'currency': currency,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Account fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 11) {
      row.add('');
    }
    return Account(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      type: AccountType.values.firstWhere(
        (e) => e.name == row[2]?.toString(),
        orElse: () => AccountType.other,
      ),
      initialBalance: double.tryParse(row[3]?.toString() ?? '0') ?? 0,
      currency: row[4]?.toString() ?? 'USD',
      icon: row[5]?.toString() ?? '',
      color: int.tryParse(row[6]?.toString() ?? '0') ?? 0xFF808080,
      sortOrder: int.tryParse(row[7]?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(row[8]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row[9]?.toString() ?? '') ?? DateTime.now(),
      deletedAt: row[10]?.toString().isNotEmpty == true
          ? DateTime.tryParse(row[10].toString())
          : null,
    );
  }
}

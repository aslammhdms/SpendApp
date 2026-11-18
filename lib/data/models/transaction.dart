import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType {
  @JsonValue('expense')
  expense,
  @JsonValue('income')
  income,
  @JsonValue('transfer')
  transfer,
}

@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required String id,
    required DateTime date,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    String? toAccountId,
    String? note,
    String? receiptUrl,
    String? recurringId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
  bool get isTransfer => type == TransactionType.transfer;

  double get signedAmount {
    switch (type) {
      case TransactionType.expense:
        return -amount.abs();
      case TransactionType.income:
        return amount.abs();
      case TransactionType.transfer:
        return amount;
    }
  }

  Transaction copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'account_id': accountId,
      'to_account_id': toAccountId ?? '',
      'note': note ?? '',
      'receipt_url': receiptUrl ?? '',
      'recurring_id': recurringId ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Transaction fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 13) {
      row.add('');
    }
    return Transaction(
      id: row[0]?.toString() ?? '',
      date: DateTime.tryParse(row[1]?.toString() ?? '') ?? DateTime.now(),
      amount: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
      type: TransactionType.values.firstWhere(
        (e) => e.name == row[3]?.toString(),
        orElse: () => TransactionType.expense,
      ),
      categoryId: row[4]?.toString() ?? '',
      accountId: row[5]?.toString() ?? '',
      toAccountId: row[6]?.toString().isNotEmpty == true ? row[6].toString() : null,
      note: row[7]?.toString().isNotEmpty == true ? row[7].toString() : null,
      receiptUrl: row[8]?.toString().isNotEmpty == true ? row[8].toString() : null,
      recurringId: row[9]?.toString().isNotEmpty == true ? row[9].toString() : null,
      createdAt: DateTime.tryParse(row[10]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row[11]?.toString() ?? '') ?? DateTime.now(),
      deletedAt: row[12]?.toString().isNotEmpty == true
          ? DateTime.tryParse(row[12].toString())
          : null,
    );
  }
}

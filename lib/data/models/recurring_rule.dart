import 'package:freezed_annotation/freezed_annotation.dart';
import 'transaction.dart';

part 'recurring_rule.freezed.dart';
part 'recurring_rule.g.dart';

enum RecurringFrequency {
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
  @JsonValue('monthly')
  monthly,
  @JsonValue('yearly')
  yearly,
}

@freezed
class RecurringRule with _$RecurringRule {
  const RecurringRule._();

  const factory RecurringRule({
    required String id,
    required String name,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    required RecurringFrequency frequency,
    @Default(1) int interval,
    required DateTime nextDueDate,
    DateTime? endDate,
    String? note,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _RecurringRule;

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      _$RecurringRuleFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isDue => isActive && nextDueDate.isBefore(DateTime.now());
  bool get hasEnded => endDate != null && endDate!.isBefore(DateTime.now());

  DateTime calculateNextDueDate() {
    switch (frequency) {
      case RecurringFrequency.daily:
        return nextDueDate.add(Duration(days: interval));
      case RecurringFrequency.weekly:
        return nextDueDate.add(Duration(days: 7 * interval));
      case RecurringFrequency.monthly:
        return DateTime(
          nextDueDate.year,
          nextDueDate.month + interval,
          nextDueDate.day,
        );
      case RecurringFrequency.yearly:
        return DateTime(
          nextDueDate.year + interval,
          nextDueDate.month,
          nextDueDate.day,
        );
    }
  }

  RecurringRule copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'account_id': accountId,
      'frequency': frequency.name,
      'interval': interval,
      'next_due_date': nextDueDate.toIso8601String(),
      'end_date': endDate?.toIso8601String() ?? '',
      'note': note ?? '',
      'is_active': isActive ? '1' : '0',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static RecurringRule fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 15) row.add('');
    return RecurringRule(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      amount: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
      type: TransactionType.values.firstWhere(
        (e) => e.name == row[3]?.toString(),
        orElse: () => TransactionType.expense,
      ),
      categoryId: row[4]?.toString() ?? '',
      accountId: row[5]?.toString() ?? '',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == row[6]?.toString(),
        orElse: () => RecurringFrequency.monthly,
      ),
      interval: int.tryParse(row[7]?.toString() ?? '1') ?? 1,
      nextDueDate: DateTime.parse(row[8]?.toString() ?? DateTime.now().toIso8601String()),
      endDate: row[9]?.toString().isNotEmpty == true
          ? DateTime.parse(row[9].toString())
          : null,
      note: row[10]?.toString().isNotEmpty == true ? row[10].toString() : null,
      isActive: row[11]?.toString() == '1',
      createdAt: DateTime.parse(row[12]?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(row[13]?.toString() ?? DateTime.now().toIso8601String()),
      deletedAt: row[14]?.toString().isNotEmpty == true
          ? DateTime.parse(row[14].toString())
          : null,
    );
  }
}

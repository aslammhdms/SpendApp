import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

enum BudgetPeriod {
  @JsonValue('weekly')
  weekly,
  @JsonValue('monthly')
  monthly,
  @JsonValue('yearly')
  yearly,
}

@freezed
class Budget with _$Budget {
  const Budget._();

  const factory Budget({
    required String id,
    required String name,
    required double amount,
    required BudgetPeriod period,
    String? categoryId,
    required DateTime startDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    @Default(0) double spentAmount,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isOverall => categoryId == null;

  double get remaining => amount - spentAmount;
  double get percentUsed => amount > 0 ? (spentAmount / amount) : 0;
  bool get isOverBudget => spentAmount > amount;
  bool get isWarning => percentUsed >= 0.8 && percentUsed < 1.0;

  Budget copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'period': period.name,
      'category_id': categoryId ?? '',
      'start_date': startDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Budget fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 9) row.add('');
    return Budget(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      amount: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
      period: BudgetPeriod.values.firstWhere(
        (e) => e.name == row[3]?.toString(),
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryId: row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
      startDate: DateTime.tryParse(row[5]?.toString() ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(row[6]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row[7]?.toString() ?? '') ?? DateTime.now(),
      deletedAt: row[8]?.toString().isNotEmpty == true
          ? DateTime.tryParse(row[8].toString())
          : null,
    );
  }
}

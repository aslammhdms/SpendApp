import 'package:freezed_annotation/freezed_annotation.dart';

part 'loan.freezed.dart';
part 'loan.g.dart';

enum LoanType {
  @JsonValue('lent')
  lent,
  @JsonValue('borrowed')
  borrowed,
}

@freezed
abstract class Loan with _$Loan {
  const Loan._();

  const factory Loan({
    required String id,
    required String personId,
    required LoanType type,
    required double amount,
    String? note,
    required DateTime date,
    @Default(false) bool isSettlement,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Loan;

  factory Loan.fromJson(Map<String, dynamic> json) => _$LoanFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isLent => type == LoanType.lent;
  bool get isBorrowed => type == LoanType.borrowed;

  Loan copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'person_id': personId,
      'type': type.name,
      'amount': amount,
      'note': note ?? '',
      'date': date.toIso8601String(),
      'is_settlement': isSettlement ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Loan fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 10) row.add('');
    return Loan(
      id: row[0]?.toString() ?? '',
      personId: row[1]?.toString() ?? '',
      type: LoanType.values.firstWhere(
        (e) => e.name == row[2]?.toString(),
        orElse: () => LoanType.lent,
      ),
      amount: double.tryParse(row[3]?.toString() ?? '0') ?? 0,
      note: row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
      date: DateTime.tryParse(row[5]?.toString() ?? '') ?? DateTime.now(),
      isSettlement: row[6]?.toString() == '1',
      createdAt: DateTime.tryParse(row[7]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row[8]?.toString() ?? '') ?? DateTime.now(),
      deletedAt: row[9]?.toString().isNotEmpty == true
          ? DateTime.tryParse(row[9].toString())
          : null,
    );
  }
}

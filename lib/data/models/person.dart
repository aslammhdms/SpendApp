import 'package:freezed_annotation/freezed_annotation.dart';

part 'person.freezed.dart';
part 'person.g.dart';

@freezed
abstract class Person with _$Person {
  const Person._();

  const factory Person({
    required String id,
    required String name,
    String? phone,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    @Default(0) double netBalance,
  }) = _Person;

  factory Person.fromJson(Map<String, dynamic> json) =>
      _$PersonFromJson(json);

  bool get isDeleted => deletedAt != null;

  Person copyWithDelete() => copyWith(deletedAt: DateTime.now());

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'phone': phone ?? '',
      'note': note ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Person fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 7) {
      row.add('');
    }
    return Person(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      phone: row[2]?.toString().isNotEmpty == true ? row[2].toString() : null,
      note: row[3]?.toString().isNotEmpty == true ? row[3].toString() : null,
      createdAt: DateTime.tryParse(row[4]?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row[5]?.toString() ?? '') ?? DateTime.now(),
      deletedAt: row[6]?.toString().isNotEmpty == true
          ? DateTime.tryParse(row[6].toString())
          : null,
    );
  }
}

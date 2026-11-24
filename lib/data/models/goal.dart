import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal.freezed.dart';
part 'goal.g.dart';

/// Money being put aside for something, such as a new phone. The saved
/// amount is kept on the goal itself rather than taken from transactions,
/// so putting money towards a goal does not count as spending.
@freezed
abstract class Goal with _$Goal {
  const Goal._();

  const factory Goal({
    required String id,
    required String name,
    required double targetAmount,
    @Default(0) double savedAmount,
    DateTime? targetDate,
    required String icon,
    required int color,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// Saved share of the target, from 0 to 1.
  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0;

  bool get isReached => targetAmount > 0 && savedAmount >= targetAmount;

  double get remaining =>
      (targetAmount - savedAmount).clamp(0, double.infinity).toDouble();

  /// What to save each month from [now] to reach the target by its date.
  /// Null without a date, once reached, or when the date has passed.
  double? monthlyToReach(DateTime now) {
    final date = targetDate;
    if (date == null || isReached) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (!date.isAfter(today)) return null;
    var months = (date.year - now.year) * 12 + date.month - now.month;
    if (date.day > now.day) months++;
    if (months < 1) months = 1;
    return remaining / months;
  }

  Map<String, dynamic> toSheetRow() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String() ?? '',
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String() ?? '',
    };
  }

  static Goal fromSheetRow(List<dynamic> row) {
    // Pad row — Sheets API strips trailing empty cells
    while (row.length < 10) {
      row.add('');
    }
    String cell(int i) => row[i]?.toString() ?? '';
    return Goal(
      id: cell(0),
      name: cell(1),
      targetAmount: double.tryParse(cell(2)) ?? 0,
      savedAmount: double.tryParse(cell(3)) ?? 0,
      targetDate: cell(4).isNotEmpty ? DateTime.tryParse(cell(4)) : null,
      icon: cell(5).isNotEmpty ? cell(5) : '💰',
      color: int.tryParse(cell(6)) ?? 0xFF0E6E7A,
      createdAt: DateTime.tryParse(cell(7)) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(cell(8)) ?? DateTime.now(),
      deletedAt: cell(9).isNotEmpty ? DateTime.tryParse(cell(9)) : null,
    );
  }
}

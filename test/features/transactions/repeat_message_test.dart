import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/recurring_rule.dart';
import 'package:spendsheet/features/transactions/screens/add_edit_transaction_screen.dart';

void main() {
  test('says which payment was added as well, and when the next one is', () {
    expect(
      repeatSavedMessage(
        frequency: RecurringFrequency.monthly,
        firstDate: DateTime(2026, 10, 24),
        caughtUp: [DateTime(2026, 11, 24)],
        next: DateTime(2026, 12, 24),
      ),
      'Saved for Oct 24, 2026. The payment due on Nov 24, 2026 was added '
      'too. Every month, next on Dec 24, 2026.',
    );
  });

  test('counts several payments caught up at once', () {
    final message = repeatSavedMessage(
      frequency: RecurringFrequency.weekly,
      firstDate: DateTime(2026, 11, 2),
      caughtUp: [
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 23),
      ],
      next: DateTime(2026, 11, 30),
    );
    expect(message, contains('3 payments due since then were added too'));
    expect(message, contains('the latest on Nov 23, 2026'));
  });

  test('says nothing extra when nothing was due yet', () {
    expect(
      repeatSavedMessage(
        frequency: RecurringFrequency.monthly,
        firstDate: DateTime(2026, 11, 24),
        caughtUp: const [],
        next: DateTime(2026, 12, 24),
      ),
      'Saved for Nov 24, 2026. Every month, next on Dec 24, 2026.',
    );
  });
}

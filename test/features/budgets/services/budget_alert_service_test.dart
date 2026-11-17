import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsheet/core/services/notification_service.dart';
import 'package:spendsheet/data/models/app_settings.dart';
import 'package:spendsheet/data/models/budget.dart';
import 'package:spendsheet/features/budgets/services/budget_alert_service.dart';

import '../../../helpers/mock_repositories.dart';

typedef ShownAlert = ({int id, String title, String body});

/// Records alerts instead of showing them.
class _RecordingNotifications extends NotificationService {
  final List<ShownAlert> shown = [];
  Object? failWith;

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (failWith != null) throw failWith!;
    shown.add((id: id, title: title, body: body));
  }
}

Budget _budget({
  String id = 'b1',
  String name = 'Groceries',
  double amount = 500,
  double spent = 0,
  BudgetPeriod period = BudgetPeriod.monthly,
}) {
  final created = DateTime(2026, 1, 1);
  return Budget(
    id: id,
    name: name,
    amount: amount,
    period: period,
    startDate: created,
    createdAt: created,
    updatedAt: created,
    spentAmount: spent,
  );
}

void main() {
  late MockSettingsRepository settingsRepo;
  late _RecordingNotifications notifications;
  late DateTime now;
  late BudgetAlertService alerts;

  void useSettings(AppSettings settings) {
    when(() => settingsRepo.getSettings()).thenAnswer((_) async => settings);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settingsRepo = MockSettingsRepository();
    useSettings(const AppSettings());
    notifications = _RecordingNotifications();
    now = DateTime(2026, 11, 17, 10);
    alerts = BudgetAlertService(
      settings: settingsRepo,
      notifications: notifications,
      now: () => now,
    );
  });

  test('stays quiet below 80% of the budget', () async {
    await alerts.check([_budget(spent: 399)]);

    expect(notifications.shown, isEmpty);
  });

  test('alerts once when spending reaches 80%', () async {
    await alerts.check([_budget(spent: 425)]);
    await alerts.check([_budget(spent: 430)]);

    expect(notifications.shown, hasLength(1));
    expect(notifications.shown.single.title, 'Groceries budget at 85%');
    expect(
      notifications.shown.single.body,
      r"You've spent $425.00 of $500.00 this month. $75.00 left.",
    );
  });

  test('alerts again when the budget is used up, then stays quiet', () async {
    await alerts.check([_budget(spent: 425)]);
    await alerts.check([_budget(spent: 500)]);
    await alerts.check([_budget(spent: 520)]);

    expect(notifications.shown.map((a) => a.title), [
      'Groceries budget at 85%',
      'Groceries budget used up',
    ]);
    expect(
      notifications.shown.last.body,
      r"You've spent $500.00 of $500.00 this month.",
    );
  });

  test('going straight past the budget sends a single alert', () async {
    await alerts.check([_budget(spent: 520)]);

    expect(notifications.shown, hasLength(1));
    expect(notifications.shown.single.title, 'Groceries budget exceeded');
    expect(
      notifications.shown.single.body,
      r"You've spent $520.00 of $500.00 this month, $20.00 over.",
    );
  });

  test('alerts again in the next budget period', () async {
    await alerts.check([_budget(spent: 425)]);
    now = DateTime(2026, 12, 2);
    await alerts.check([_budget(spent: 425)]);

    expect(notifications.shown, hasLength(2));
  });

  test('alerts again if spending drops back and then climbs again', () async {
    await alerts.check([_budget(spent: 425)]);
    await alerts.check([_budget(spent: 300)]); // an expense was deleted
    await alerts.check([_budget(spent: 425)]);

    expect(notifications.shown, hasLength(2));
  });

  test('each budget alerts on its own', () async {
    await alerts.check([
      _budget(id: 'food', name: 'Food', spent: 420),
      _budget(id: 'fun', name: 'Fun', amount: 100, spent: 90),
      _budget(id: 'home', name: 'Home', spent: 10),
    ]);

    expect(notifications.shown.map((a) => a.title), [
      'Food budget at 84%',
      'Fun budget at 90%',
    ]);
    expect(notifications.shown[0].id, isNot(notifications.shown[1].id));
  });

  test('describes weekly and yearly budgets by their period', () async {
    await alerts.check([
      _budget(id: 'w', period: BudgetPeriod.weekly, spent: 450),
      _budget(id: 'y', period: BudgetPeriod.yearly, spent: 450),
    ]);

    expect(notifications.shown[0].body, contains('this week'));
    expect(notifications.shown[1].body, contains('this year'));
  });

  test('formats amounts in the currency from settings', () async {
    useSettings(const AppSettings(currency: 'EUR'));

    await alerts.check([_budget(spent: 425)]);

    expect(notifications.shown.single.body, contains('€425.00'));
  });

  test('sends nothing while budget alerts are off', () async {
    useSettings(const AppSettings(budgetAlertsEnabled: false));

    await alerts.check([_budget(spent: 520)]);

    expect(notifications.shown, isEmpty);
  });

  test('sends nothing while notifications are off', () async {
    useSettings(const AppSettings(notificationsEnabled: false));

    await alerts.check([_budget(spent: 520)]);

    expect(notifications.shown, isEmpty);
  });

  test('ignores budgets with no amount and deleted budgets', () async {
    await alerts.check([
      _budget(id: 'zero', amount: 0, spent: 50),
      _budget(id: 'gone', spent: 520).copyWithDelete(),
    ]);

    expect(notifications.shown, isEmpty);
  });

  test('retries an alert that failed to show', () async {
    notifications.failWith = Exception('notifications unavailable');
    await alerts.check([_budget(spent: 425)]);

    notifications.failWith = null;
    await alerts.check([_budget(spent: 425)]);

    expect(notifications.shown, hasLength(1));
  });
}

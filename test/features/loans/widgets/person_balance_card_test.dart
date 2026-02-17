import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/person.dart';
import 'package:spendsheet/features/loans/widgets/person_balance_card.dart';

Person _makePerson({
  String id = 'per_1',
  String name = 'Alice',
  double netBalance = 0,
}) {
  final now = DateTime.now();
  return Person(
    id: id,
    name: name,
    createdAt: now,
    updatedAt: now,
    netBalance: netBalance,
  );
}

void main() {
  Widget buildTestWidget({
    required Person person,
    String currency = 'USD',
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PersonBalanceCard(
          person: person,
          currency: currency,
          onTap: onTap,
          onDelete: onDelete,
        ),
      ),
    );
  }

  group('PersonBalanceCard', () {
    testWidgets('positive balance shows "owes you"', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        person: _makePerson(name: 'Alice', netBalance: 200),
      ));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('owes you'), findsOneWidget);
    });

    testWidgets('negative balance shows "you owe"', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        person: _makePerson(name: 'Bob', netBalance: -150),
      ));

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('you owe'), findsOneWidget);
    });

    testWidgets('zero balance shows "settled"', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        person: _makePerson(name: 'Charlie', netBalance: 0),
      ));

      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('settled'), findsOneWidget);
    });

    testWidgets('shows person initial in CircleAvatar', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        person: _makePerson(name: 'Dave'),
      ));

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('person name displayed', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        person: _makePerson(name: 'Eve'),
      ));

      expect(find.text('Eve'), findsOneWidget);
    });
  });
}

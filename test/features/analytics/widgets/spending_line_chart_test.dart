import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/analytics/widgets/spending_line_chart.dart';

void main() {
  group('SpendingLineChart', () {
    testWidgets('renders "No spending data" when dailySpending is empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendingLineChart(dailySpending: {}),
          ),
        ),
      );

      expect(find.text('No spending data'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('renders chart WITHOUT CRASH when all values are 0',
        (tester) async {
      final data = {
        DateTime(2024, 1, 1): 0.0,
        DateTime(2024, 1, 2): 0.0,
        DateTime(2024, 1, 3): 0.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineChart(dailySpending: data),
          ),
        ),
      );

      // Should not crash — should render chart title
      expect(find.text('Daily Spending'), findsOneWidget);
      // Should NOT show the empty state message
      expect(find.text('No spending data'), findsNothing);
    });

    testWidgets('renders chart with normal data', (tester) async {
      final data = {
        DateTime(2024, 1, 1): 50.0,
        DateTime(2024, 1, 2): 120.0,
        DateTime(2024, 1, 3): 75.0,
        DateTime(2024, 1, 4): 200.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineChart(dailySpending: data),
          ),
        ),
      );

      expect(find.text('Daily Spending'), findsOneWidget);
    });

    testWidgets('renders chart with single data point', (tester) async {
      final data = {
        DateTime(2024, 1, 1): 100.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineChart(dailySpending: data),
          ),
        ),
      );

      expect(find.text('Daily Spending'), findsOneWidget);
    });

    testWidgets('handles very large values without crash', (tester) async {
      final data = {
        DateTime(2024, 1, 1): 999999999.99,
        DateTime(2024, 1, 2): 888888888.88,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineChart(dailySpending: data),
          ),
        ),
      );

      expect(find.text('Daily Spending'), findsOneWidget);
    });
  });
}

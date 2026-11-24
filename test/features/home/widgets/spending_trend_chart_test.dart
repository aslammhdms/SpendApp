import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/features/home/widgets/spending_trend_chart.dart';

void main() {
  Widget buildTestWidget({
    Map<DateTime, double> dailySpending = const {},
    String currency = 'USD',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SpendingTrendChart(
            dailySpending: dailySpending,
            currency: currency,
          ),
        ),
      ),
    );
  }

  group('SpendingTrendChart', () {
    testWidgets('empty data shows "No spending data yet"', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No spending data yet'), findsOneWidget);
    });

    testWidgets('renders chart when data provided', (tester) async {
      final now = DateTime.now();
      final data = {
        DateTime(now.year, now.month, now.day - 2): 50.0,
        DateTime(now.year, now.month, now.day - 1): 30.0,
        DateTime(now.year, now.month, now.day): 75.0,
      };

      await tester.pumpWidget(buildTestWidget(dailySpending: data));

      expect(find.text('No spending data yet'), findsNothing);
      expect(find.text('Spending Trend'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('shows title and subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Spending Trend'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('single day of data renders correctly', (tester) async {
      final now = DateTime.now();
      final data = {DateTime(now.year, now.month, now.day): 100.0};

      await tester.pumpWidget(buildTestWidget(dailySpending: data));

      expect(find.text('Spending Trend'), findsOneWidget);
      // Should render Today label
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('7 days of data renders without error', (tester) async {
      final now = DateTime.now();
      final data = <DateTime, double>{};
      for (int i = 6; i >= 0; i--) {
        data[DateTime(now.year, now.month, now.day - i)] = 10.0 * (7 - i);
      }

      await tester.pumpWidget(buildTestWidget(dailySpending: data));

      expect(find.text('Spending Trend'), findsOneWidget);
    });
  });
}

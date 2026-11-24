import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendsheet/core/theme/app_theme.dart';
import 'package:spendsheet/shared/widgets/add_menu_fab.dart';
import 'package:spendsheet/shared/widgets/app_loader.dart';
import 'package:spendsheet/shared/widgets/segmented_list.dart';
import 'package:spendsheet/shared/widgets/wavy_progress_bar.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AppLoader', () {
    testWidgets('morphs between shapes without errors', (tester) async {
      await tester.pumpWidget(_host(const AppLoader()));
      // Through several shape changes, including the wrap to the first.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
      expect(tester.getSize(find.byType(AppLoader)), const Size(48, 48));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('is a plain spinner when animations are off', (tester) async {
      await tester.pumpWidget(_host(const AppLoader(), reduceMotion: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('WavyProgressBar', () {
    testWidgets('draws every amount of progress', (tester) async {
      for (final value in [0.0, 0.01, 0.3, 0.99, 1.0, 1.7, double.nan]) {
        await tester.pumpWidget(_host(
          SizedBox(width: 200, child: WavyProgressBar(value: value)),
        ));
        expect(tester.takeException(), isNull, reason: 'value $value');
      }
    });

    testWidgets('tells screen readers how far along it is', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 200,
        child: WavyProgressBar(value: 0.3, semanticsLabel: 'Laptop progress'),
      )));
      final node = tester.getSemantics(find.byType(WavyProgressBar));
      expect(node.label, 'Laptop progress');
      expect(node.value, '30%');
    });
  });

  group('AddMenuFab', () {
    Widget app({bool reduceMotion = false}) {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Text('home'),
            floatingActionButton: AddMenuFab(),
          ),
        ),
        GoRoute(
          path: '/transactions/add',
          builder: (_, state) =>
              Scaffold(body: Text('add ${state.uri.queryParameters['type']}')),
        ),
      ]);
      return MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      );
    }

    testWidgets('offers the four kinds and opens the one chosen',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Add transaction'));
      await tester.pumpAndSettle();

      for (final label in ['Expense', 'Income', 'Transfer', 'Loan']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('add income'), findsOneWidget);
    });

    testWidgets('closes without adding anything', (tester) async {
      await tester.pumpWidget(app(reduceMotion: true));
      await tester.tap(find.byTooltip('Add transaction'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Income'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('each choice is at least 48dp tall', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Add transaction'));
      await tester.pumpAndSettle();

      final height = tester
          .getSize(find.ancestor(
              of: find.text('Loan'), matching: find.byType(InkWell)))
          .height;
      expect(height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('SegmentedList rounds only the outer corners of the group',
      (tester) async {
    await tester.pumpWidget(_host(const SegmentedList(children: [
      SizedBox(height: 40, child: Text('a')),
      SizedBox(height: 40, child: Text('b')),
      SizedBox(height: 40, child: Text('c')),
    ])));
    BorderRadius radiusOf(String label) {
      final material = tester.widget<Material>(find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first);
      return (material.shape! as RoundedRectangleBorder).borderRadius
          as BorderRadius;
    }

    expect(radiusOf('a').topLeft.x, greaterThan(radiusOf('a').bottomLeft.x));
    expect(radiusOf('b').topLeft, radiusOf('b').bottomLeft);
    expect(radiusOf('c').bottomLeft.x, greaterThan(radiusOf('c').topLeft.x));
  });
}

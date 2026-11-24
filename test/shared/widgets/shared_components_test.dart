import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/theme/app_theme.dart';
import 'package:spendsheet/core/theme/tokens.dart';
import 'package:spendsheet/features/transactions/widgets/amount_input_pad.dart';
import 'package:spendsheet/shared/widgets/bottom_action_bar.dart';
import 'package:spendsheet/shared/widgets/app_dialog.dart';
import 'package:spendsheet/shared/widgets/app_menu.dart';
import 'package:spendsheet/shared/widgets/app_sheet.dart';
import 'package:spendsheet/shared/widgets/segmented_control.dart';

Widget _host(Widget home, {bool highContrast = false, double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        highContrast: highContrast,
        textScaler: TextScaler.linear(textScale),
      ),
      child: app!,
    ),
    home: home,
  );
}

void main() {
  group('SegmentedControl', () {
    Widget control(String selected, ValueChanged<String> onChanged) => _host(
          Scaffold(
            body: SegmentedControl<String>(
              segments: const {'w': 'Week', 'm': 'Month', 'y': 'Year'},
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        );

    testWidgets('reports the segment that is tapped', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(control('m', picked.add));

      await tester.tap(find.text('Year'));

      expect(picked, ['y']);
    });

    testWidgets('does nothing when the selected segment is tapped',
        (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(control('m', picked.add));

      await tester.tap(find.text('Month'));

      expect(picked, isEmpty);
    });

    testWidgets('marks the selected segment for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(control('m', (_) {}));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Month')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Week')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('each segment is a 48dp touch target', (tester) async {
      await tester.pumpWidget(control('m', (_) {}));

      final segment = tester.getSize(
        find
            .ancestor(of: find.text('Week'), matching: find.byType(InkWell))
            .first,
      );
      expect(segment.height, greaterThanOrEqualTo(Sizes.touchTarget));
    });
  });

  group('AppMenuButton', () {
    Widget menu(ValueChanged<String> onSelected, {bool highContrast = false}) =>
        _host(
          Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: AppMenuButton<String>(
                tooltip: 'Options',
                onSelected: onSelected,
                items: const [
                  AppMenuItem(value: 'edit', label: 'Edit'),
                  AppMenuItem(
                      value: 'delete', label: 'Delete', destructive: true),
                ],
              ),
            ),
          ),
          highContrast: highContrast,
        );

    testWidgets('opens and reports the choice', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(menu(chosen.add));

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(chosen, ['delete']);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('closes without a choice when tapped outside', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(menu(chosen.add));

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 500));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('stays on screen next to a button in the corner',
        (tester) async {
      await tester.pumpWidget(menu((_) {}));

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(MaterialApp));
      final item = tester.getRect(find.text('Delete'));
      expect(item.right, lessThanOrEqualTo(screen.width));
      expect(item.left, greaterThanOrEqualTo(0));
    });
  });

  group('AppAlertDialog', () {
    Widget opener({double textScale = 1}) => _host(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AppAlertDialog(
                    title: const Text('Delete Budget'),
                    content: const Text(
                        'Are you sure you want to delete this budget?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(onPressed: () {}, child: const Text('Delete')),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          textScale: textScale,
        );

    testWidgets('shows title, message and actions', (tester) async {
      await tester.pumpWidget(opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Budget'), findsOneWidget);
      expect(find.textContaining('Are you sure'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Budget'), findsNothing);
    });

    testWidgets('fits a small phone at 1.3x text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(opener(textScale: 1.3));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Delete').hitTestable(), findsOneWidget);
    });
  });

  group('showAppSheet', () {
    testWidgets('shows the content with a drag handle',
        (tester) async {
      await tester.pumpWidget(_host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (_) => const ListTile(title: Text('In the sheet')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('In the sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BottomActionBar', () {
    testWidgets('holds its action clear of the screen edge', (tester) async {
      await tester.pumpWidget(_host(
        Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomActionBar(
            child: FilledButton(onPressed: () {}, child: const Text('Save')),
          ),
        ),
      ));

      final screen = tester.getSize(find.byType(MaterialApp));
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.height, greaterThanOrEqualTo(Sizes.touchTarget));
      expect(screen.height - button.bottom, greaterThanOrEqualTo(Space.md));
    });
  });

  group('AmountInputPad', () {
    testWidgets('fits a small phone at 1.3x text with a middle section',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        Scaffold(
          appBar: AppBar(title: const Text('Add Transaction')),
          body: AmountInputPad(
            onAmountChanged: (_) {},
            middle: const SizedBox(height: 130, child: Placeholder()),
          ),
          bottomNavigationBar: BottomActionBar(
            child: FilledButton(onPressed: () {}, child: const Text('Save')),
          ),
        ),
        textScale: 1.3,
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('9').hitTestable(), findsOneWidget);
      expect(find.text('Enter amount'), findsOneWidget);
    });

    testWidgets('every key is a 48dp touch target', (tester) async {
      await tester.pumpWidget(_host(
        Scaffold(body: AmountInputPad(onAmountChanged: (_) {})),
      ));

      for (final key in ['1', '5', '0', '.']) {
        final size = tester.getSize(
          find
              .ancestor(of: find.text(key), matching: find.byType(InkWell))
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(Sizes.touchTarget));
        expect(size.width, greaterThanOrEqualTo(Sizes.touchTarget));
      }
    });
  });
}

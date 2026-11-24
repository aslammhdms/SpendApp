import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/theme/app_theme.dart';
import 'package:spendsheet/shared/widgets/screen_insets.dart';

Widget _host(Widget child, {bool highContrast = false, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: app!,
    ),
    home: child,
  );
}

void main() {
  group('App bar', () {
    Widget screen({bool highContrast = false}) =>
        _host(const _Screen(), highContrast: highContrast);

    testWidgets('the first row starts below the bar', (tester) async {
      await tester.pumpWidget(screen());

      final barBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(tester.getTopLeft(find.text('row 0')).dy,
          greaterThanOrEqualTo(barBottom));
    });

    testWidgets('content does scroll behind the bar', (tester) async {
      await tester.pumpWidget(screen());

      await tester.drag(find.byType(ListView), const Offset(0, -30));
      await tester.pumpAndSettle();

      final barBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(tester.getTopLeft(find.text('row 0')).dy, lessThan(barBottom));
    });
  });
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Title')),
      body: ListView(
        padding: ScreenInsets.of(context),
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 48, child: Text('row $i')),
        ],
      ),
    );
  }
}

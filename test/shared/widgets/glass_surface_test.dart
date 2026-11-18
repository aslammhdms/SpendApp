import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/theme/app_theme.dart';
import 'package:spendsheet/core/theme/tokens.dart';
import 'package:spendsheet/shared/widgets/glass_app_bar.dart';
import 'package:spendsheet/shared/widgets/glass_surface.dart';
import 'package:spendsheet/shared/widgets/screen_insets.dart';

const _solid = Color(0xFF123456);

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

Color? _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  group('GlassSurface', () {
    testWidgets('blurs what is behind it and tints by the bar token',
        (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(solidColor: _solid, child: Text('on glass')),
      ));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(_fill(tester)!.a, closeTo(Glass.barTintOpacity, 0.005));
      expect(find.text('on glass'), findsOneWidget);
    });

    testWidgets('sheets are less see-through than bars', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(solidColor: _solid, level: GlassLevel.sheet),
      ));

      expect(_fill(tester)!.a, closeTo(Glass.sheetTintOpacity, 0.005));
      expect(Glass.sheetTintOpacity, greaterThan(Glass.barTintOpacity));
    });

    testWidgets('clips the blur to its own shape', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(solidColor: _solid, borderRadius: Radii.xlAll),
      ));

      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, Radii.xlAll);
    });

    testWidgets('is solid, with no blur, when high contrast is on',
        (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(solidColor: _solid, child: Text('on glass')),
        highContrast: true,
      ));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(_fill(tester), _solid);
      expect(find.text('on glass'), findsOneWidget);
    });

    testWidgets('skips the blur while its intensity is zero', (tester) async {
      await tester.pumpWidget(_host(
        const GlassSurface(solidColor: _solid, intensity: 0),
      ));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(_fill(tester)!.a, 0);
    });

    test('tint opacities stay above the calculated AA minimums', () {
      // Worst backdrop: pure black in light mode, pure white in dark.
      // See docs/DESIGN.md, "Glass".
      expect(Glass.barTintOpacity, greaterThanOrEqualTo(0.75));
      expect(Glass.sheetTintOpacity, greaterThanOrEqualTo(0.91));
    });
  });

  group('GlassAppBar', () {
    Widget screen({bool highContrast = false}) =>
        _host(const _Screen(), highContrast: highContrast);

    testWidgets('is clear at the top and turns to glass once scrolled under',
        (tester) async {
      await tester.pumpWidget(screen());
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
    });

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

    testWidgets('never blurs when high contrast is on', (tester) async {
      await tester.pumpWidget(screen(highContrast: true));

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Title')),
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

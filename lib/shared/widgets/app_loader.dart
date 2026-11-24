import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// The app's "working on it" indicator: a filled shape that turns while it
/// changes from one Material shape into the next.
///
/// Use it for waits of unknown length in place of a spinner. With the
/// system's "remove animations" setting on it falls back to the standard
/// circular indicator, which that setting leaves moving slowly.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.size = 48, this.color});

  /// Width and height of the space it takes; the shape is a little smaller.
  final double size;

  /// Fill color; the primary color when null.
  final Color? color;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  /// The sequence Material's loading indicator steps through.
  static final List<RoundedPolygon> _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];

  /// Time spent on each shape, the change into it included.
  static const Duration _perShape = Duration(milliseconds: 650);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _perShape * _shapes.length,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox.square(
        dimension: widget.size,
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.15),
          child: CircularProgressIndicator(color: color),
        ),
      );
    }
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final position = _controller.value * _shapes.length;
            final index = position.floor() % _shapes.length;
            // Each change springs in, then the shape rests.
            final t = Motion.spatialFast.transform(position - position.floor());
            final shape = ShapeBorder.lerp(
              MaterialShapeBorder(shape: _shapes[index]),
              MaterialShapeBorder(
                  shape: _shapes[(index + 1) % _shapes.length]),
              t.clamp(0.0, 1.0),
            )!;
            return Transform.rotate(
              // A steady turn, plus a push with every change of shape.
              angle: (position * 0.5 + (index + t) * 0.25) * math.pi,
              child: Padding(
                padding: EdgeInsets.all(widget.size * 0.1),
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: color, shape: shape),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

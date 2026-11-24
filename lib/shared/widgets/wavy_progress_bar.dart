import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// A progress bar whose filled part is a wave: Material's expressive
/// progress indicator. The part still to go is a flat track with a dot at
/// its end. Once [value] reaches 1 the wave flattens into a full bar.
///
/// Use it where progress is something to feel good about (a savings goal),
/// and the plain [LinearProgressIndicator] where it is a limit (a budget).
class WavyProgressBar extends StatelessWidget {
  const WavyProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  /// From 0 to 1.
  final double value;
  final Color? color;
  final Color? trackColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  static const double height = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(shown * 100).round()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WavePainter(
            value: shown,
            color: color ?? scheme.primary,
            trackColor: trackColor ?? scheme.surfaceContainerHighest,
            rightToLeft: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.rightToLeft,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final bool rightToLeft;

  static const double _stroke = 4;
  static const double _amplitude = 3;
  static const double _wavelength = 28;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (rightToLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final y = size.height / 2;
    const start = _stroke / 2;
    final end = size.width - _stroke / 2;
    final split = start + (end - start) * value;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    if (value < 1) {
      final trackStart = value == 0 ? start : split + _gap + _stroke / 2;
      if (trackStart < end) {
        canvas.drawLine(
            Offset(trackStart, y), Offset(end, y), line..color = trackColor);
      }
      // The stop: a dot marking where the bar ends.
      canvas.drawCircle(Offset(end, y), _stroke / 2, Paint()..color = color);
    }
    if (value == 0) return;

    final path = Path()..moveTo(start, y);
    if (value >= 1) {
      path.lineTo(end, y);
    } else {
      for (var x = start; x <= split; x += 1) {
        // The wave grows from flat at its start, so the bar's end cap
        // stays on the center line.
        final grow = ((x - start) / _wavelength).clamp(0.0, 1.0);
        path.lineTo(
          x,
          y + math.sin((x - start) / _wavelength * 2 * math.pi) *
              _amplitude *
              grow,
        );
      }
    }
    canvas.drawPath(path, line..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      value != old.value ||
      color != old.color ||
      trackColor != old.trackColor ||
      rightToLeft != old.rightToLeft;
}

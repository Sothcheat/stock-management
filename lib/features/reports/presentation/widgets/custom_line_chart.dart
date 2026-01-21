import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> dataPoints;
  final List<String> xLabels;
  final double height;
  final Color color;

  const CustomLineChart({
    super.key,
    required this.dataPoints,
    required this.xLabels,
    this.height = 300,
    this.color = SoftColors.brandPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            "No data to display",
            style: GoogleFonts.outfit(color: SoftColors.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          dataPoints: dataPoints,
          xLabels: xLabels,
          color: color,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> xLabels;
  final Color color;

  _ChartPainter({
    required this.dataPoints,
    required this.xLabels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(50, 16, 24, 30);
    final chartRect = Rect.fromLTRB(
      padding.left,
      padding.top,
      size.width - padding.right,
      size.height - padding.bottom,
    );

    _drawAxes(canvas, chartRect);
    _drawData(canvas, chartRect);
  }

  void _drawAxes(Canvas canvas, Rect rect) {
    final maxY = dataPoints.reduce((a, b) => a > b ? a : b);
    final displayMaxY = maxY > 0 ? maxY * 1.2 : 100.0;
    const ySteps = 5;

    // Draw Y Axis Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= ySteps; i++) {
      final value = (displayMaxY / ySteps) * i;
      final y = rect.bottom - (rect.height / ySteps) * i;

      String labelText;
      if (value >= 1000) {
        labelText = '${(value / 1000).toStringAsFixed(1)}k';
      } else {
        labelText = value.toInt().toString();
      }

      // Hide 0 if desired, or keep it. Let's keep it but formatted simply.
      if (value == 0) labelText = '0';

      textPainter.text = TextSpan(
        text: labelText,
        style: GoogleFonts.outfit(
          color: SoftColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left - textPainter.width - 12, y - textPainter.height / 2),
      );
    }

    // Draw X Axis Labels
    if (xLabels.isNotEmpty) {
      final stepX = rect.width / (xLabels.length - 1);
      for (int i = 0; i < xLabels.length; i++) {
        final x = rect.left + stepX * i;
        final label = xLabels[i];

        textPainter.text = TextSpan(
          text: label,
          style: GoogleFonts.outfit(
            color: SoftColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();

        // Center text on X coord, ensuring it doesn't go off bounds
        double drawX = x - textPainter.width / 2;

        // Simple bounds check
        // if (i == 0) drawX = x; // Left align first
        // if (i == xLabels.length - 1) drawX = x - textPainter.width; // Right align last

        textPainter.paint(canvas, Offset(drawX, rect.bottom + 8));
      }
    }
  }

  void _drawData(Canvas canvas, Rect rect) {
    if (dataPoints.length < 2) return;

    final maxY = dataPoints.reduce((a, b) => a > b ? a : b);
    final displayMaxY = maxY > 0 ? maxY * 1.2 : 100.0;

    final path = Path();
    final stepX = rect.width / (dataPoints.length - 1);

    // Calculate Coordinates
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final value = dataPoints[i];
      final x = rect.left + stepX * i;
      final y = rect.bottom - (value / displayMaxY) * rect.height;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);

    // Smooth Curve (Catmull-Rom spline or simple quadratic/cubic)
    // Using simple approach: lineTo for now, or quadraticBezierTo
    // Beziers might overshooting if not careful. Let's try Monotone Cubic or Catmull-Rom manually?
    // Or just simple cubicTo between midpoints.

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      // Control points for smooth curve
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Draw Shadow/Gradient below
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, rect.bottom);
    fillPath.lineTo(points.first.dx, rect.bottom);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw Stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Draw Dots
    // final dotPaint = Paint()..color = color;
    // for (var point in points) {
    //   canvas.drawCircle(point, 3, dotPaint);
    //   canvas.drawCircle(point, 1.5, Paint()..color = Colors.white);
    // }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.color != color;
  }
}

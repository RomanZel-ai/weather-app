import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/weather.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart({super.key, required this.items});

  final List<HourlyForecast> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().subtract(const Duration(hours: 1));
    final nextHours = items.where((item) => item.time.isAfter(now)).take(24).toList();

    if (nextHours.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Нет почасовых данных для графика'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'График температуры',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ближайшие 24 часа',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.58),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(
                painter: _TemperatureChartPainter(
                  items: nextHours,
                  lineColor: colorScheme.primary,
                  gridColor: colorScheme.outlineVariant,
                  textColor: colorScheme.onSurface.withOpacity(0.68),
                  pointColor: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemperatureChartPainter extends CustomPainter {
  const _TemperatureChartPainter({
    required this.items,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.pointColor,
  });

  final List<HourlyForecast> items;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 12.0;
    const top = 16.0;
    const bottom = 36.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final temperatures = items.map((item) => item.temperature).toList();
    final minTemp = temperatures.reduce(math.min).floorToDouble() - 1;
    final maxTemp = temperatures.reduce(math.max).ceilToDouble() + 1;
    final range = math.max(1.0, maxTemp - minTemp);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);

      final value = (maxTemp - range * i / 3).round();
      textPainter.text = TextSpan(
        text: '$value°',
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 7));
    }

    final points = <Offset>[];

    for (var i = 0; i < items.length; i++) {
      final x = left + chartWidth * i / math.max(1, items.length - 1);
      final normalized = (items[i].temperature - minTemp) / range;
      final y = top + chartHeight * (1 - normalized);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, top + chartHeight)
      ..lineTo(points.first.dx, top + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withOpacity(0.22),
          lineColor.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    final pointPaint = Paint()..color = pointColor;

    for (var i = 0; i < points.length; i++) {
      if (i % 4 != 0 && i != points.length - 1) continue;

      final point = points[i];
      canvas.drawCircle(point, 4, pointPaint);

      final hour = items[i].time.hour.toString().padLeft(2, '0');
      textPainter.text = TextSpan(
        text: '$hour:00',
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, size.height - 22));

      textPainter.text = TextSpan(
        text: '${items[i].temperature.round()}°',
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, point.dy - 24));
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor;
  }
}

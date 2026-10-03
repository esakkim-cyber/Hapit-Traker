import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/activity_session_model.dart';

class RouteMapPainter extends CustomPainter {
  final List<GpsPointModel> points;
  final bool isDark;

  RouteMapPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.darkBorder : AppColors.lightBorder)
          .withValues(alpha: 0.3)
      ..strokeWidth = 1;

    const double gridSize = 30.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) {
      // Draw waiting indicator
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Acquiring GPS Signal...',
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    if (points.length == 1) {
      // Draw single point center
      final center = Offset(size.width / 2, size.height / 2);
      final pointPaint = Paint()..color = AppColors.primary;
      canvas.drawCircle(center, 8, pointPaint);
      return;
    }

    // Find bounding box of lat/lng
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;
    if (latRange == 0) latRange = 0.0001;
    if (lngRange == 0) lngRange = 0.0001;

    const double padding = 36.0;
    final double drawWidth = size.width - (padding * 2);
    final double drawHeight = size.height - (padding * 2);

    Offset toCanvasOffset(GpsPointModel p) {
      final double normalizedX = (p.longitude - minLng) / lngRange;
      final double normalizedY = 1.0 - ((p.latitude - minLat) / latRange);
      return Offset(
        padding + (normalizedX * drawWidth),
        padding + (normalizedY * drawHeight),
      );
    }

    // Build polyline path
    final path = Path();
    final firstOffset = toCanvasOffset(points.first);
    path.moveTo(firstOffset.dx, firstOffset.dy);

    for (int i = 1; i < points.length; i++) {
      final offset = toCanvasOffset(points[i]);
      path.lineTo(offset.dx, offset.dy);
    }

    // Draw route glow
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Draw route polyline
    final routePaint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    // Draw Start Point Marker (Green)
    final startPaint = Paint()..color = AppColors.accentEmerald;
    final startBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(firstOffset, 7, startPaint);
    canvas.drawCircle(firstOffset, 7, startBorder);

    // Draw End / Current Position Marker (Primary Pulse)
    final lastOffset = toCanvasOffset(points.last);
    final currentPulse = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35);
    final currentPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(lastOffset, 12, currentPulse);
    canvas.drawCircle(lastOffset, 7, currentPaint);
    canvas.drawCircle(lastOffset, 7, startBorder);
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        !listEquals(oldDelegate.points, points);
  }
}

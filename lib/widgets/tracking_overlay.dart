import 'package:flutter/material.dart';

import '../services/tracking_renderer.dart';

class TrackingOverlay extends StatelessWidget {
  final TrackingRenderer renderer;
  final double time;

  const TrackingOverlay({
    super.key,
    required this.renderer,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrackingPainter(renderer, time),
    );
  }
}

class _TrackingPainter extends CustomPainter {
  final TrackingRenderer renderer;
  final double time;

  _TrackingPainter(this.renderer, this.time);

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, time);

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) => true;
}

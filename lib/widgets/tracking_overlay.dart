import 'package:flutter/material.dart';

import '../models/tracker_config.dart';
import '../services/tracking_renderer.dart';

class TrackingOverlay extends StatelessWidget {
  final List<TrackerConfig> configs;
  final TrackingMode mode;
  final double visibleDuration;
  final double time;

  const TrackingOverlay({
    super.key,
    required this.configs,
    required this.mode,
    required this.visibleDuration,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrackingPainter(configs, mode, visibleDuration, time),
    );
  }
}

class _TrackingPainter extends CustomPainter {
  final List<TrackerConfig> configs;
  final TrackingMode mode;
  final double visibleDuration;
  final double time;

  _TrackingPainter(this.configs, this.mode, this.visibleDuration, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    TrackingRenderer.paint(canvas, size, time, configs, mode, visibleDuration);
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) => true;
}

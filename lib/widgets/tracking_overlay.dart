import 'package:flutter/material.dart';

import '../models/tracker_config.dart';
import '../services/tracking_renderer.dart';

class TrackingOverlay extends StatelessWidget {
  final List<TrackerConfig> configs;
  final TrackingMode mode;
  final double visibleDuration;
  final double time;
  final Color color;
  final bool webEnabled;

  const TrackingOverlay({
    super.key,
    required this.configs,
    required this.mode,
    required this.visibleDuration,
    required this.time,
    required this.color,
    required this.webEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrackingPainter(
        configs,
        mode,
        visibleDuration,
        time,
        color,
        webEnabled,
      ),
    );
  }
}

class _TrackingPainter extends CustomPainter {
  final List<TrackerConfig> configs;
  final TrackingMode mode;
  final double visibleDuration;
  final double time;
  final Color color;
  final bool webEnabled;

  _TrackingPainter(
    this.configs,
    this.mode,
    this.visibleDuration,
    this.time,
    this.color,
    this.webEnabled,
  );

  @override
  void paint(Canvas canvas, Size size) {
    TrackingRenderer.paint(
      canvas,
      size,
      time,
      configs,
      mode,
      visibleDuration,
      color,
      webEnabled,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) => true;
}

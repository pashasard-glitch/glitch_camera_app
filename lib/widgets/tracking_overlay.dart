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
  final bool spotlight;

  const TrackingOverlay({
    super.key,
    required this.configs,
    required this.mode,
    required this.visibleDuration,
    required this.time,
    required this.color,
    required this.webEnabled,
    required this.spotlight,
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
        spotlight,
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
  final bool spotlight;

  _TrackingPainter(
    this.configs,
    this.mode,
    this.visibleDuration,
    this.time,
    this.color,
    this.webEnabled,
    this.spotlight,
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
      spotlight,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) => true;
}

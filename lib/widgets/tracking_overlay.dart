import 'dart:math';

import 'package:flutter/material.dart';

class TrackingOverlay extends StatefulWidget {
  const TrackingOverlay({super.key});

  @override
  State<TrackingOverlay> createState() => _TrackingOverlayState();
}

class _Target {
  final double baseX;
  final double baseY;
  final double ampX;
  final double ampY;
  final double speed;
  final double phase;
  final double size;
  final String label;
  final String tag;

  _Target({
    required this.baseX,
    required this.baseY,
    required this.ampX,
    required this.ampY,
    required this.speed,
    required this.phase,
    required this.size,
    required this.label,
    required this.tag,
  });
}

class _TrackingOverlayState extends State<TrackingOverlay>
    with SingleTickerProviderStateMixin {
  static const _labels = [
    'TRACKING',
    'SCANNING',
    'LOCKED',
    'ANALYZING',
    'MATCH',
    'ID CONF.',
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  final _rand = Random();
  late List<_Target> _targets;

  @override
  void initState() {
    super.initState();
    _targets = List.generate(4, (i) {
      final label = _labels[_rand.nextInt(_labels.length)];
      final tag = 'OBJ_${(_rand.nextInt(90) + 10)}';
      return _Target(
        baseX: 0.15 + _rand.nextDouble() * 0.7,
        baseY: 0.15 + _rand.nextDouble() * 0.6,
        ampX: 0.05 + _rand.nextDouble() * 0.1,
        ampY: 0.05 + _rand.nextDouble() * 0.1,
        speed: 0.5 + _rand.nextDouble() * 1.5,
        phase: _rand.nextDouble() * pi * 2,
        size: 70 + _rand.nextDouble() * 50,
        label: label,
        tag: tag,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * pi * 2;
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _TrackerPainter(targets: _targets, t: t),
            );
          },
        );
      },
    );
  }
}

class _TrackerPainter extends CustomPainter {
  final List<_Target> targets;
  final double t;

  _TrackerPainter({required this.targets, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final target in targets) {
      final cx = (target.baseX +
              target.ampX * sin(t * target.speed + target.phase)) *
          size.width;
      final cy = (target.baseY +
              target.ampY * cos(t * target.speed * 0.8 + target.phase)) *
          size.height;
      final s = target.size;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: s, height: s);

      final blink = (sin(t * target.speed * 3 + target.phase) + 1) / 2;
      boxPaint.color = Colors.cyanAccent.withOpacity(0.5 + blink * 0.5);

      _drawCorners(canvas, rect, boxPaint);

      final pct = 60 + ((sin(t * target.speed + target.phase) + 1) * 20);
      final text =
          '${target.tag}\n${target.label} ${pct.toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.cyanAccent.withOpacity(0.5 + blink * 0.5),
            fontSize: 11,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 140);
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height - 4));
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    final len = rect.shortestSide * 0.25;

    void corner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
    }

    corner(rect.topLeft, Offset(len, 0), Offset(0, len));
    corner(rect.topRight, Offset(-len, 0), Offset(0, len));
    corner(rect.bottomLeft, Offset(len, 0), Offset(0, -len));
    corner(rect.bottomRight, Offset(-len, 0), Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant _TrackerPainter oldDelegate) => true;
}

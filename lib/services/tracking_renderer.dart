import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrackingBox {
  final Rect rect;
  final String tag;
  final String label;
  final double glow;
  final double pct;

  TrackingBox({
    required this.rect,
    required this.tag,
    required this.label,
    required this.glow,
    required this.pct,
  });
}

class _TargetDef {
  final int seed;
  final double baseX;
  final double baseY;
  final double rangeX;
  final double rangeY;
  final double sizeFrac;
  final double interval;
  final double phase;
  final String tag;
  final String label;

  _TargetDef({
    required this.seed,
    required this.baseX,
    required this.baseY,
    required this.rangeX,
    required this.rangeY,
    required this.sizeFrac,
    required this.interval,
    required this.phase,
    required this.tag,
    required this.label,
  });
}

/// Декоративный "AR-трекинг": рамки резко перескакивают в новое положение
/// через равные промежутки времени, а не плавно едут по экрану.
class TrackingRenderer {
  static const _labels = [
    'TRACKING',
    'SCANNING',
    'LOCKED',
    'ANALYZING',
    'MATCH',
    'ID CONF.',
  ];

  final List<_TargetDef> _targets;

  TrackingRenderer({int count = 4, int? seed})
      : _targets = _generate(count, seed);

  static List<_TargetDef> _generate(int count, int? seed) {
    final rand = math.Random(seed);
    return List.generate(count, (i) {
      return _TargetDef(
        seed: rand.nextInt(1 << 30),
        baseX: 0.18 + rand.nextDouble() * 0.6,
        baseY: 0.18 + rand.nextDouble() * 0.55,
        rangeX: 0.06 + rand.nextDouble() * 0.1,
        rangeY: 0.06 + rand.nextDouble() * 0.1,
        sizeFrac: 0.15 + rand.nextDouble() * 0.08,
        // Держит положение 0.35–0.85 сек, потом резкий скачок.
        interval: 0.35 + rand.nextDouble() * 0.5,
        phase: rand.nextDouble() * 6,
        tag: 'OBJ_${10 + rand.nextInt(89)}',
        label: _labels[rand.nextInt(_labels.length)],
      );
    });
  }

  int _mix(int seed, int k) {
    var n = seed * 374761393 + k * 668265263;
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return n & 0x7fffffff;
  }

  double _hash(int seed, int k) => _mix(seed, k) / 0x7fffffff;

  Offset _jumpOffset(_TargetDef t, int k) {
    final hx = _hash(t.seed, k * 2);
    final hy = _hash(t.seed, k * 2 + 1);
    return Offset((hx * 2 - 1) * t.rangeX, (hy * 2 - 1) * t.rangeY);
  }

  List<TrackingBox> boxesAt(double time, Size size) {
    final minSide = math.min(size.width, size.height);

    return _targets.map((t) {
      final localT = (time + t.phase) / t.interval;
      final k = localT.floor();
      final frac = localT - k;

      // Скачок занимает первые 25% интервала, дальше рамка стоит на месте.
      const snapFraction = 0.25;
      final snapT = (frac / snapFraction).clamp(0.0, 1.0);
      final inv = 1 - snapT;
      final eased = 1 - inv * inv * inv;

      final offA = _jumpOffset(t, k);
      final offB = _jumpOffset(t, k + 1);
      final off = Offset(
        offA.dx + (offB.dx - offA.dx) * eased,
        offA.dy + (offB.dy - offA.dy) * eased,
      );

      // Небольшая высокочастотная дрожь поверх скачков.
      final shakeX = math.sin(time * 23 + t.phase * 7) * 0.006;
      final shakeY = math.cos(time * 19 + t.phase * 5) * 0.006;

      final cx = (t.baseX + off.dx + shakeX) * size.width;
      final cy = (t.baseY + off.dy + shakeY) * size.height;
      final boxSize = t.sizeFrac * minSide;

      final blink = (math.sin(time * 6 + t.phase * 3) + 1) / 2;
      final pct = 55 + _hash(t.seed, k) * 40;

      return TrackingBox(
        rect: Rect.fromCenter(
          center: Offset(cx, cy),
          width: boxSize,
          height: boxSize,
        ),
        tag: t.tag,
        label: t.label,
        glow: (0.4 + blink * 0.6).clamp(0.0, 1.0),
        pct: pct,
      );
    }).toList();
  }

  void paint(Canvas canvas, Size size, double time) {
    if (size.width <= 0 || size.height <= 0) return;
    final boxes = boxesAt(time, size);
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final b in boxes) {
      boxPaint.color = Colors.cyanAccent.withOpacity(b.glow);
      _drawCorners(canvas, b.rect, boxPaint);

      final text = '${b.tag}\n${b.label} ${b.pct.toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.cyanAccent.withOpacity(b.glow),
            fontSize: 11,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      tp.paint(canvas, Offset(b.rect.left, b.rect.top - tp.height - 4));
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
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tracker_config.dart';

class TrackingBox {
  final Rect rect;
  final String tag;
  final String label;
  final double glow;
  final bool dense;

  TrackingBox({
    required this.rect,
    required this.tag,
    required this.label,
    required this.glow,
    required this.dense,
  });
}

/// Декоративный "AR-трекинг". Чистые функции от времени — одинаковый
/// результат что на экране, что при вшивании в сохранённое фото/видео.
class TrackingRenderer {
  static const _glyphs = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&@*';
  static const int _meshNeighbors = 2;

  static int _mix(int seed, int k) {
    var n = seed * 374761393 + k * 668265263;
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return n & 0x7fffffff;
  }

  static double _hash(int seed, int k) => _mix(seed, k) / 0x7fffffff;

  static String _fastTag(int seed, int segment, {int length = 5}) {
    final sb = StringBuffer();
    for (int i = 0; i < length; i++) {
      final h = _hash(seed * 977 + i * 131, segment);
      final idx = (h * _glyphs.length).floor().clamp(0, _glyphs.length - 1);
      sb.write(_glyphs[idx]);
    }
    return sb.toString();
  }

  static String _hexTag(int seed) {
    final v = _mix(seed, 0) % 256;
    return '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  static List<TrackingBox> boxesAt({
    required double time,
    required Size size,
    required List<TrackerConfig> configs,
    required TrackingMode mode,
    required double visibleDuration,
    required bool spotlight,
  }) {
    if (configs.isEmpty || size.width <= 0 || size.height <= 0) return [];
    final minSide = math.min(size.width, size.height);
    final boxes = <TrackingBox>[];
    final alwaysOn = mode != TrackingMode.random;

    // "Фокус по очереди": в любой момент виден только один трекер,
    // остальные скрыты, интервал переключения — тот же ползунок времени.
    int? spotlightIndex;
    double spotlightRamp = 1.0;
    if (spotlight) {
      final interval = math.max(0.2, visibleDuration);
      final k = (time / interval).floor();
      spotlightIndex = k % configs.length;
      final phase = time - k * interval;
      spotlightRamp = (phase / (interval * 0.3)).clamp(0.0, 1.0);
    }

    for (int i = 0; i < configs.length; i++) {
      final c = configs[i];
      final seed = c.id.hashCode & 0x7fffffff;
      final gap = visibleDuration * (0.35 + _hash(seed, 999) * 0.5);
      final cycleLen = math.max(0.05, visibleDuration + gap);
      final k = (time / cycleLen).floor();
      final phase = time - k * cycleLen;

      final bool visible =
          spotlight ? (i == spotlightIndex) : (alwaysOn || phase < visibleDuration);
      if (!visible) continue;

      double cx, cy;
      if (mode == TrackingMode.grid && !spotlight) {
        final cols = math.max(1, math.sqrt(configs.length).ceil());
        final rows = (configs.length / cols).ceil();
        final col = i % cols;
        final row = i ~/ cols;
        cx = (col + 0.5) / cols * size.width;
        cy = (row + 0.5) / rows * size.height;
      } else if (mode == TrackingMode.focus && !spotlight) {
        final angle = i * 2.399963;
        final radius = 0.06 * minSide * math.sqrt(i + 1);
        cx = size.width / 2 + math.cos(angle) * radius;
        cy = size.height / 2 + math.sin(angle) * radius;
      } else {
        final hx = _hash(seed, k * 2);
        final hy = _hash(seed, k * 2 + 1);
        cx = (0.15 + hx * 0.7) * size.width;
        cy = (0.15 + hy * 0.65) * size.height;
      }

      final shakeX = math.sin(time * 23 + seed % 17) * minSide * 0.004;
      final shakeY = math.cos(time * 19 + seed % 13) * minSide * 0.004;

      final boxSize = c.sizeFrac * minSide * (spotlight ? 1.25 : 1.0);
      final blink = (math.sin(time * 6 + seed % 11) + 1) / 2;
      final segment = (time / 0.06).floor();
      final isDense = c.label.isEmpty;

      final tag = isDense
          ? (c.randomTag ? _fastTag(seed, segment, length: 3) : _hexTag(seed))
          : (c.randomTag
              ? _fastTag(seed, segment)
              : 'OBJ_${10 + (_hash(seed, 0) * 89).floor()}');

      var glow = (0.45 + blink * 0.55).clamp(0.0, 1.0);
      if (spotlight) {
        glow = (glow * (0.3 + 0.7 * spotlightRamp)).clamp(0.0, 1.0);
      }

      boxes.add(TrackingBox(
        rect: Rect.fromCenter(
          center: Offset(cx + shakeX, cy + shakeY),
          width: boxSize,
          height: boxSize,
        ),
        tag: tag,
        label: c.label,
        glow: glow,
        dense: isDense,
      ));
    }
    return boxes;
  }

  static void _drawMesh(
    Canvas canvas,
    List<TrackingBox> targets,
    Color color,
  ) {
    if (targets.length < 2) return;
    final linePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1;
    final n = targets.length;
    final drawn = <int>{};

    for (int i = 0; i < n; i++) {
      final dists = <MapEntry<int, double>>[];
      for (int j = 0; j < n; j++) {
        if (i == j) continue;
        final d =
            (targets[i].rect.center - targets[j].rect.center).distanceSquared;
        dists.add(MapEntry(j, d));
      }
      dists.sort((a, b) => a.value.compareTo(b.value));

      for (final e in dists.take(_meshNeighbors)) {
        final j = e.key;
        final key = i < j ? i * 100000 + j : j * 100000 + i;
        if (drawn.add(key)) {
          canvas.drawLine(
              targets[i].rect.center, targets[j].rect.center, linePaint);
        }
      }
    }
  }

  static void paint(
    Canvas canvas,
    Size size,
    double time,
    List<TrackerConfig> configs,
    TrackingMode mode,
    double visibleDuration,
    Color color,
    bool webEnabled,
    bool spotlight,
  ) {
    final boxes = boxesAt(
      time: time,
      size: size,
      configs: configs,
      mode: mode,
      visibleDuration: visibleDuration,
      spotlight: spotlight,
    );

    final meshTargets =
        webEnabled ? boxes : boxes.where((b) => b.dense).toList();
    _drawMesh(canvas, meshTargets, color);

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final b in boxes) {
      boxPaint.color = color.withOpacity(b.glow);

      if (b.dense) {
        canvas.drawRect(b.rect, boxPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: b.tag,
            style: TextStyle(
              color: color.withOpacity(b.glow),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, b.rect.topLeft + const Offset(4, 2));
      } else {
        _drawCorners(canvas, b.rect, boxPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: '${b.label}\n${b.tag}',
            style: TextStyle(
              color: color.withOpacity(b.glow),
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
  }

  static void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
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

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Простой скан-панорама: угол поворота считается интегрированием
/// гироскопа (dead reckoning, может немного плыть на длинных сканах).
/// Кадры ставятся рядом по расчётному углу, без анализа содержимого —
/// это не полноценный CV-стич, а приближённая угловая склейка.
class PanoramaService {
  static const double captureStepDegrees = 18.0;
  static const double assumedFovDegrees = 60.0;

  double _yaw = 0.0;
  double _lastCaptureYaw = 0.0;
  DateTime? _lastSampleTime;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  int eventCount = 0;
  double lastRawY = 0.0;
  String? lastError;

  final List<ui.Image> _frames = [];
  final List<double> _yaws = [];

  double get yaw => _yaw;
  int get frameCount => _frames.length;

  void start() {
    _yaw = 0;
    _lastCaptureYaw = 0;
    _lastSampleTime = null;
    eventCount = 0;
    lastRawY = 0.0;
    lastError = null;
    _frames.clear();
    _yaws.clear();
    _gyroSub = gyroscopeEventStream().listen(
      (event) {
        eventCount++;
        lastRawY = event.y;
        final now = DateTime.now();
        if (_lastSampleTime != null) {
          final dt = now.difference(_lastSampleTime!).inMicroseconds / 1e6;
          // event.y — поворот вокруг вертикальной оси телефона, держим
          // портретно. Если направление окажется зеркальным на твоём
          // телефоне, поменяй знак на минус.
          _yaw += event.y * dt * 180 / math.pi;
        }
        _lastSampleTime = now;
      },
      onError: (e) {
        lastError = e.toString();
      },
      cancelOnError: false,
    );
  }

  void stop() {
    _gyroSub?.cancel();
    _gyroSub = null;
  }

  /// Проверяет, пора ли снимать кадр, и сразу "бронирует" эту точку —
  /// вызывать не чаще одного раза за реальный кадр камеры.
  bool shouldCapture() {
    if ((_yaw - _lastCaptureYaw).abs() >= captureStepDegrees) {
      _lastCaptureYaw = _yaw;
      return true;
    }
    return false;
  }

  void addFrame(ui.Image frame, double yawAtCapture) {
    _frames.add(frame);
    _yaws.add(yawAtCapture);
  }

  Future<ui.Image?> stitch() async {
    if (_frames.isEmpty) return null;
    if (_frames.length == 1) return _frames.first;

    final frameW = _frames.first.width.toDouble();
    final frameH = _frames.first.height.toDouble();
    final pxPerDeg = frameW / assumedFovDegrees;

    final minYaw = _yaws.reduce(math.min);
    final maxYaw = _yaws.reduce(math.max);
    final totalWidth = ((maxYaw - minYaw) * pxPerDeg + frameW).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalWidth.toDouble(), frameH),
      Paint()..color = Colors.black,
    );

    final order = List<int>.generate(_frames.length, (i) => i)
      ..sort((a, b) => _yaws[a].compareTo(_yaws[b]));

    for (int idx = 0; idx < order.length; idx++) {
      final i = order[idx];
      final img = _frames[i];
      final x = (_yaws[i] - minYaw) * pxPerDeg - frameW / 2;

      if (idx == 0) {
        canvas.drawImage(img, Offset(x, 0), Paint());
        continue;
      }

      final prevYaw = _yaws[order[idx - 1]];
      final overlapDeg = math.max(
        0.0,
        prevYaw + assumedFovDegrees / 2 - (_yaws[i] - assumedFovDegrees / 2),
      );
      final overlapPx = (overlapDeg * pxPerDeg).clamp(0.0, frameW * 0.9);

      canvas.saveLayer(Rect.fromLTWH(x, 0, frameW, frameH), Paint());
      canvas.drawImage(img, Offset(x, 0), Paint());
      if (overlapPx > 1) {
        final fadeRect = Rect.fromLTWH(x, 0, overlapPx, frameH);
        final gradientPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, 0),
            Offset(x + overlapPx, 0),
            const [Color(0x00000000), Color(0xFF000000)],
          )
          ..blendMode = BlendMode.dstIn;
        canvas.drawRect(fadeRect, gradientPaint);
      }
      canvas.restore();
    }

    final picture = recorder.endRecording();
    return picture.toImage(totalWidth, frameH.toInt());
  }
}

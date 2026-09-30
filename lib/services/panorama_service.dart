import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Скан панорамы по двум осям: поворот вокруг себя (yaw, гироскоп,
/// накопление угла) и наклон телефона вверх-вниз (pitch, акселерометр,
/// абсолютное значение без накопления ошибки).
/// Склейка — приближённая, по углу, без анализа содержимого кадра.
class PanoramaService {
  static const double captureStepYaw = 18.0;
  static const double captureStepPitch = 15.0;
  static const double assumedFovDegrees = 60.0;
  static const int maxFrames = 200;

  double _yaw = 0.0;
  double _pitch = 0.0;
  double _lastCaptureYaw = 1000;
  double _lastCapturePitch = 1000;
  DateTime? _lastGyroTime;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final List<ui.Image> _frames = [];
  final List<double> _yaws = [];
  final List<double> _pitches = [];

  double get yaw => _yaw;
  double get pitch => _pitch;
  int get frameCount => _frames.length;
  bool get isFull => _frames.length >= maxFrames;

  void start() {
    _yaw = 0;
    _pitch = 0;
    _lastCaptureYaw = 1000;
    _lastCapturePitch = 1000;
    _lastGyroTime = null;
    _frames.clear();
    _yaws.clear();
    _pitches.clear();

    _gyroSub = gyroscopeEventStream().listen((event) {
      final now = DateTime.now();
      if (_lastGyroTime != null) {
        final dt = now.difference(_lastGyroTime!).inMicroseconds / 1e6;
        // Если поворот в приложении идёт в обратную сторону от реального —
        // поменяй знак на минус.
        _yaw += event.y * dt * 180 / math.pi;
      }
      _lastGyroTime = now;
    });

    _accelSub = accelerometerEventStream().listen((event) {
      // Абсолютный наклон от вертикали держания телефона (камерой от себя).
      // Если "вверх" и "вниз" перепутаны местами — поменяй знак на минус.
      final target =
          math.atan2(-event.z, event.y) * 180 / math.pi;
      _pitch = _pitch * 0.8 + target * 0.2;
    });
  }

  void stop() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _accelSub?.cancel();
    _accelSub = null;
  }

  /// Проверяет, пора ли снимать кадр в текущей точке (yaw, pitch),
  /// и сразу "бронирует" эту точку.
  bool shouldCapture() {
    if (isFull) return false;
    final movedYaw = (_yaw - _lastCaptureYaw).abs() >= captureStepYaw;
    final movedPitch = (_pitch - _lastCapturePitch).abs() >= captureStepPitch;
    if (movedYaw || movedPitch) {
      _lastCaptureYaw = _yaw;
      _lastCapturePitch = _pitch;
      return true;
    }
    return false;
  }

  void addFrame(ui.Image frame, double yawAtCapture, double pitchAtCapture) {
    _frames.add(frame);
    _yaws.add(yawAtCapture);
    _pitches.add(pitchAtCapture.clamp(-85.0, 85.0));
  }

  /// Возвращает готовую равнопрямоугольную панораму (2:1) — верх/низ
  /// останутся чёрными там, где не снималось.
  Future<ui.Image?> stitch() async {
    if (_frames.isEmpty) return null;

    const totalWidth = 2048;
    const totalHeight = totalWidth ~/ 2;
    final pxPerDeg = totalWidth / 360.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight.toDouble()),
      Paint()..color = Colors.black,
    );

    for (int i = 0; i < _frames.length; i++) {
      final img = _frames[i];
      final aspect = img.height / img.width;
      final w = assumedFovDegrees * pxPerDeg;
      final h = w * aspect;

      var yawNorm = _yaws[i] % 360.0;
      if (yawNorm < 0) yawNorm += 360.0;
      final x = yawNorm / 360.0 * totalWidth - w / 2;
      final y = (90.0 - _pitches[i]) / 180.0 * totalHeight - h / 2;

      final dst = Rect.fromLTWH(x, y, w, h);
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(img, src, dst, Paint());

      // Копия у левого/правого края, чтобы шов на 0°/360° не был пустым.
      if (x < w) {
        canvas.drawImageRect(
            img, src, dst.shift(const Offset(totalWidth.toDouble(), 0)), Paint());
      }
      if (x + w > totalWidth - w) {
        canvas.drawImageRect(
            img, src, dst.shift(const Offset(-totalWidth.toDouble(), 0)), Paint());
      }
    }

    final picture = recorder.endRecording();
    return picture.toImage(totalWidth, totalHeight);
  }
}

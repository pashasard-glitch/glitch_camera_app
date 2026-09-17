import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Определяет только "портрет или бок" и сразу отдаёт готовый угол
/// поворота для шейдера — 90° для портрета, 270° для бокового положения.
/// Подобрано опытным путём под конкретное устройство/камеру.
class OrientationService {
  int _rotationDegrees = 90;
  int get rotationDegrees => _rotationDegrees;

  StreamSubscription<AccelerometerEvent>? _sub;
  final void Function(int rotationDegrees)? onChanged;

  OrientationService({this.onChanged});

  void start() {
    _sub = accelerometerEventStream().listen((event) {
      final x = event.x;
      final y = event.y;

      if (x.abs() < 2 && y.abs() < 2) return;

      final isPortrait = y.abs() > x.abs();
      final newRotation = isPortrait ? 90 : 270;

      if (newRotation != _rotationDegrees) {
        _rotationDegrees = newRotation;
        onChanged?.call(_rotationDegrees);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

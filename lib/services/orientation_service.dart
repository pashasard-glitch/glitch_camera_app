import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Положение телефона по акселерометру.
/// deviceRotation: 0 = обычное вертикальное, 90 = повёрнут против часовой
/// (верх слева), 180 = вверх ногами, 270 = повёрнут по часовой (верх справа).
class OrientationService {
  int _deviceRotation = 0;
  int get deviceRotation => _deviceRotation;

  StreamSubscription<AccelerometerEvent>? _sub;
  final void Function(int deviceRotation)? onChanged;

  OrientationService({this.onChanged});

  void start() {
    _sub = accelerometerEventStream().listen((event) {
      final x = event.x;
      final y = event.y;

      // Телефон лежит плашмя: угол по экрану не определить, оставляем прежний.
      if (math.sqrt(x * x + y * y) < 4.0) return;

      // Направление «вверх» в системе координат телефона.
      var angle = math.atan2(x, y) * 180 / math.pi;
      if (angle < 0) angle += 360;

      // Кратчайшая разница с текущим положением.
      var diff = (angle - _deviceRotation).abs();
      if (diff > 180) diff = 360 - diff;

      // Гистерезис: переключаемся, только когда ушли заметно дальше 45°.
      if (diff < 60) return;

      final snapped = ((angle / 90).round() * 90) % 360;
      if (snapped != _deviceRotation) {
        _deviceRotation = snapped;
        onChanged?.call(snapped);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

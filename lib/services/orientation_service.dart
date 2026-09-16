import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class OrientationService {
  int _rotation = 0;
  int get rotation => _rotation;

  StreamSubscription<AccelerometerEvent>? _sub;
  final void Function(int rotation)? onChanged;

  OrientationService({this.onChanged});

  void start() {
    _sub = accelerometerEventStream().listen((event) {
      final x = event.x;
      final y = event.y;

      if (x.abs() < 3 && y.abs() < 3) return;

      int newRotation;
      if (x.abs() > y.abs()) {
        newRotation = x > 0 ? 90 : 270;
      } else {
        newRotation = y > 0 ? 0 : 180;
      }

      if (newRotation != _rotation) {
        _rotation = newRotation;
        onChanged?.call(_rotation);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

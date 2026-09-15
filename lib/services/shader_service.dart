import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ShaderService {
  ui.FragmentProgram? _program;

  ui.FragmentProgram? get program => _program;

  Future<void> load() async {
    _program = await ui.FragmentProgram.fromAsset('shaders/glitch.frag');
  }

  /// Рендерит кадр через шейдер и возвращает готовое ui.Image
  /// с уже наложенным эффектом.
  Future<ui.Image?> renderFrame({
    required ui.Image source,
    required double intensity,
    required double time,
    required int flags,
  }) async {
    if (_program == null) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
        source.height.toDouble(),
        source.width.toDouble(),
      );

      // Поворот на 90° как на экране
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(3.14159265 / 2);
      canvas.translate(-size.height / 2, -size.width / 2);

      final shader = _program!.fragmentShader();
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, time);
      shader.setFloat(3, intensity);
      shader.setFloat(4, flags.toDouble());
      shader.setImageSampler(0, source);

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = shader,
      );

      final picture = recorder.endRecording();
      return await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

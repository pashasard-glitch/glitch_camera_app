import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ShaderService {
  ui.FragmentProgram? _program;

  ui.FragmentProgram? get program => _program;

  Future<void> load() async {
    _program = await ui.FragmentProgram.fromAsset('shaders/glitch.frag');
  }

  Future<ui.Image?> renderFrame({
    required ui.Image source,
    required double intensity,
    required double time,
    required int flags,
    required int rotationDegrees,
  }) async {
    if (_program == null) return null;
    try {
      final srcW = source.width.toDouble();
      final srcH = source.height.toDouble();

      final swapDims = rotationDegrees == 90 || rotationDegrees == 270;
      final dstW = swapDims ? srcH : srcW;
      final dstH = swapDims ? srcW : srcH;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      switch (rotationDegrees) {
        case 90:
          canvas.translate(dstW, 0);
          canvas.rotate(3.14159265 / 2);
          break;
        case 180:
          canvas.translate(dstW, dstH);
          canvas.rotate(3.14159265);
          break;
        case 270:
          canvas.translate(0, dstH);
          canvas.rotate(-3.14159265 / 2);
          break;
        default:
          break;
      }

      final shader = _program!.fragmentShader();
      shader.setFloat(0, srcW);
      shader.setFloat(1, srcH);
      shader.setFloat(2, time);
      shader.setFloat(3, intensity);
      shader.setFloat(4, flags.toDouble());
      shader.setImageSampler(0, source);

      canvas.drawRect(
        Rect.fromLTWH(0, 0, srcW, srcH),
        Paint()..shader = shader,
      );

      final picture = recorder.endRecording();
      return await picture.toImage(dstW.toInt(), dstH.toInt());
    } catch (_) {
      return null;
    }
  }
}

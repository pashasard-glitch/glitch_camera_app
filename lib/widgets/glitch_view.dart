import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlitchView extends StatelessWidget {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final double intensity;
  final double time;
  final int flags;
  final int rotationDegrees;
  final bool mirror;

  const GlitchView({
    super.key,
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
    required this.flags,
    required this.rotationDegrees,
    required this.mirror,
  });

  @override
  Widget build(BuildContext context) {
    final swapDims = rotationDegrees == 90 || rotationDegrees == 270;
    final displayWidth = swapDims ? frame.height.toDouble() : frame.width.toDouble();
    final displayHeight = swapDims ? frame.width.toDouble() : frame.height.toDouble();

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: displayWidth,
        height: displayHeight,
        child: CustomPaint(
          painter: _GlitchPainter(
            program: program,
            frame: frame,
            intensity: intensity,
            time: time,
            flags: flags,
            rotationDegrees: rotationDegrees,
            mirror: mirror,
          ),
        ),
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final double intensity;
  final double time;
  final int flags;
  final int rotationDegrees;
  final bool mirror;

  _GlitchPainter({
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
    required this.flags,
    required this.rotationDegrees,
    required this.mirror,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcW = frame.width.toDouble();
    final srcH = frame.height.toDouble();
    final swapDims = rotationDegrees == 90 || rotationDegrees == 270;

    canvas.save();

    if (mirror) {
      if (swapDims) {
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
      } else {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
    }

    switch (rotationDegrees) {
      case 90:
        canvas.translate(size.width, 0);
        canvas.rotate(3.14159265 / 2);
        break;
      case 180:
        canvas.translate(size.width, size.height);
        canvas.rotate(3.14159265);
        break;
      case 270:
        canvas.translate(0, size.height);
        canvas.rotate(-3.14159265 / 2);
        break;
      default:
        break;
    }

    final shader = program.fragmentShader();
    shader.setFloat(0, srcW);
    shader.setFloat(1, srcH);
    shader.setFloat(2, time);
    shader.setFloat(3, intensity);
    shader.setFloat(4, flags.toDouble());
    shader.setImageSampler(0, frame);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, srcW, srcH),
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}

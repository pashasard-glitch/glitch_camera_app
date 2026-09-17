import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlitchView extends StatelessWidget {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final double intensity;
  final double time;
  final int flags;
  final bool mirror;

  const GlitchView({
    super.key,
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
    required this.flags,
    required this.mirror,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: frame.width.toDouble(),
        height: frame.height.toDouble(),
        child: CustomPaint(
          painter: _GlitchPainter(
            program: program,
            frame: frame,
            intensity: intensity,
            time: time,
            flags: flags,
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
  final bool mirror;

  _GlitchPainter({
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
    required this.flags,
    required this.mirror,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, intensity);
    shader.setFloat(4, flags.toDouble());
    shader.setImageSampler(0, frame);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}

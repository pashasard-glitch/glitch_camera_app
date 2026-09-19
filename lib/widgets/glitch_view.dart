import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlitchView extends StatelessWidget {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final List<double> effectIntensities;
  final double time;
  final int flags;

  const GlitchView({
    super.key,
    required this.program,
    required this.frame,
    required this.effectIntensities,
    required this.time,
    required this.flags,
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
            effectIntensities: effectIntensities,
            time: time,
            flags: flags,
          ),
        ),
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final List<double> effectIntensities;
  final double time;
  final int flags;

  _GlitchPainter({
    required this.program,
    required this.frame,
    required this.effectIntensities,
    required this.time,
    required this.flags,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, flags.toDouble());
    for (int i = 0; i < 10; i++) {
      shader.setFloat(
        4 + i,
        i < effectIntensities.length ? effectIntensities[i] : 0.8,
      );
    }
    shader.setImageSampler(0, frame);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}

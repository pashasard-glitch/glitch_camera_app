import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const GlitchCameraApp());
}

class GlitchCameraApp extends StatelessWidget {
  const GlitchCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glitch Camera',
      theme: ThemeData.dark(),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  ui.FragmentProgram? _program;
  ui.Image? _frame;
  double _intensity = 0.8;
  double _time = 0.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _setup();
    _loadShader();
    Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() => _time += 0.033);
    });
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/glitch.frag');
    setState(() => _program = program);
  }

  Future<void> _setup() async {
    if (_cameras.isEmpty) return;
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();

    await controller.startImageStream((CameraImage image) async {
      if (_busy) return;
      _busy = true;
      try {
        final uiImage = await _convertYUV(image);
        if (mounted) setState(() => _frame = uiImage);
      } catch (_) {}
      _busy = false;
    });

    if (mounted) setState(() {});
  }

  Future<ui.Image> _convertYUV(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;
    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final int uvRowStride = planeU.bytesPerRow;
    final int uvPixelStride = planeU.bytesPerPixel ?? 1;

    final Uint8List rgb = Uint8List(width * height * 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * planeY.bytesPerRow + x;
        final int uvIndex =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int Y = planeY.bytes[yIndex];
        final int U = planeU.bytes[uvIndex] - 128;
        final int V = planeV.bytes[uvIndex] - 128;

        int r = (Y + 1.402 * V).round().clamp(0, 255);
        int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        int b = (Y + 1.772 * U).round().clamp(0, 255);

        final int idx = (y * width + x) * 4;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
        rgb[idx + 3] = 255;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgb, width, height, ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: (_program == null || _frame == null)
                  ? const Center(child: CircularProgressIndicator())
                  : CustomPaint(
                      painter: _GlitchPainter(
                        program: _program!,
                        frame: _frame!,
                        intensity: _intensity,
                        time: _time,
                      ),
                    ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: _intensity,
                    min: 0.0,
                    max: 1.5,
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) => setState(() => _intensity = v),
                  ),
                  const Text(
                    'INTENSITY',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      letterSpacing: 4,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  _GlitchPainter({
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, intensity);
    shader.setImageSampler(0, frame);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}

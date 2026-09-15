

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

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
  int _flags = 1;
  bool _isRecording = false;
  int _frameCounter = 0;

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
      ResolutionPreset.low,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    await controller.initialize();
    await _startStream();
    if (mounted) setState(() {});
  }

  Future<void> _startStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.startImageStream((CameraImage image) async {
      _frameCounter++;
      if (_frameCounter % 2 != 0) return;
      if (_busy) return;
      _busy = true;
      try {
        final uiImage = await _convertYUV(image);
        if (mounted) setState(() => _frame = uiImage);
      } catch (_) {}
      _busy = false;
    });
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

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.stopImageStream();
      final XFile file = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/glitch_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await file.saveTo(path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото сохранено в галерею')),
        );
      }
      await _startStream();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка фото: $e')),
        );
      }
      await _startStream();
    }
  }

  Future<void> _toggleVideo() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isRecording) {
        final XFile file = await _controller!.stopVideoRecording();
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/glitch_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await file.saveTo(path);
        await Gal.putVideo(path);
        setState(() => _isRecording = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Видео сохранено в галерею')),
          );
        }
        await _startStream();
      } else {
        await _controller!.stopImageStream();
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запись видео...')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка видео: $e')),
        );
      }
    }
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
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _frame!.height.toDouble(),
                        height: _frame!.width.toDouble(),
                        child: Transform.rotate(
                          angle: 3.14159265 / 2,
                          child: CustomPaint(
                            painter: _GlitchPainter(
                              program: _program!,
                              frame: _frame!,
                              intensity: _intensity,
                              time: _time,
                              flags: _flags,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _showEffectMenu,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                  ),
                  child: const Icon(Icons.tune, color: Colors.cyanAccent),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent, width: 3),
                        color: Colors.black54,
                      ),
                      child:
                          const Icon(Icons.camera_alt, color: Colors.cyanAccent),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleVideo,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording
                              ? Colors.redAccent
                              : Colors.cyanAccent,
                          width: 3,
                        ),
                        color: Colors.black54,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                        color: _isRecording
                            ? Colors.redAccent
                            : Colors.cyanAccent,
                      ),
                    ),
                  ),
                ],
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

  void _showEffectMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget cb(String label, int flag) {
              final on = (_flags & flag) != 0;
              return CheckboxListTile(
                value: on,
                onChanged: (_) {
                  setState(() => _flags ^= flag);
                  setSheetState(() {});
                },
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    letterSpacing: 3,
                  ),
                ),
                activeColor: Colors.cyanAccent,
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.cyanAccent),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'EFFECTS',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  cb('RGB SPLIT', 1),
                  cb('VHS SCAN', 2),
                  cb('DATAMOSH', 4),
                  cb('NOISE', 8),
                  cb('INVERT PULSE', 16),
                  cb('ACID TINT', 32),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GlitchPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image frame;
  final double intensity;
  final double time;
  final int flags;

  _GlitchPainter({
    required this.program,
    required this.frame,
    required this.intensity,
    required this.time,
    required this.flags,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}

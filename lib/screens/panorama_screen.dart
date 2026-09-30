import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import '../services/gallery_service.dart';
import '../services/media_service.dart';
import '../services/panorama_service.dart';

class PanoramaScreen extends StatefulWidget {
  const PanoramaScreen({super.key});

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  final _camera = CameraService();
  final _panorama = PanoramaService();
  final _media = MediaService();
  final _gallery = GalleryService();

  ui.Image? _frame;
  bool _initialized = false;
  bool _scanning = false;
  bool _busy = false;
  ui.Image? _result;
  Timer? _tick;
  double _yaw = 0;
  int _shots = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _camera.init();
      await _camera.startStream((img) {
        if (mounted) setState(() => _frame = img);
        if (_scanning && _panorama.shouldCapture()) {
          final yawNow = _panorama.yaw;
          _rotateForDisplay(img).then((rotated) {
            _panorama.addFrame(rotated, yawNow);
            if (mounted) setState(() => _shots = _panorama.frameCount);
          });
        }
      });
      if (mounted) setState(() => _initialized = true);
    } catch (_) {}
  }

  Future<ui.Image> _rotateForDisplay(ui.Image source) async {
    final rotation = _camera.sensorOrientation;
    if (rotation == 0) return source;
    final srcW = source.width.toDouble();
    final srcH = source.height.toDouble();
    final isLandscape = rotation == 90 || rotation == 270;
    final dstW = isLandscape ? srcH : srcW;
    final dstH = isLandscape ? srcW : srcH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    switch (rotation) {
      case 90:
        canvas.translate(dstW, 0);
        canvas.rotate(math.pi / 2);
        break;
      case 180:
        canvas.translate(dstW, dstH);
        canvas.rotate(math.pi);
        break;
      case 270:
        canvas.translate(0, dstH);
        canvas.rotate(-math.pi / 2);
        break;
      default:
        break;
    }
    canvas.drawImage(source, Offset.zero, Paint());
    final picture = recorder.endRecording();
    return picture.toImage(dstW.toInt(), dstH.toInt());
  }

  void _startScan() {
    _panorama.start();
    setState(() {
      _scanning = true;
      _shots = 0;
      _yaw = 0;
      _result = null;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _yaw = _panorama.yaw);
    });
  }

  Future<void> _stopScan() async {
    _tick?.cancel();
    _panorama.stop();
    setState(() {
      _scanning = false;
      _busy = true;
    });
    final stitched = await _panorama.stitch();
    if (mounted) {
      setState(() {
        _result = stitched;
        _busy = false;
      });
    }
  }

  Future<void> _save() async {
    if (_result == null) return;
    try {
      await _gallery.savePhoto(_result!);
    } catch (_) {}
    await _media.saveImage(_result!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Панорама сохранена в галерею')),
      );
    }
  }

  void _discard() {
    setState(() => _result = null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _panorama.stop();
    _camera.stopStream();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: const Text('ПАНОРАМА 360',
            style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
      ),
      body: _result != null ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildResult() {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: RawImage(image: _result, fit: BoxFit.contain),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _discard,
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Заново',
                      style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton.icon(
                  onPressed: _save,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                  icon: const Icon(Icons.save, color: Colors.black),
                  label: const Text('Сохранить',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    final frame = _frame;
    final previewTurns = (_camera.sensorOrientation ~/ 90) % 4;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (frame != null)
          ClipRect(
            child: RotatedBox(
              quarterTurns: previewTurns,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: frame.width.toDouble(),
                  height: frame.height.toDouble(),
                  child: RawImage(image: frame),
                ),
              ),
            ),
          )
        else
          const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent)),
        if (_busy)
          const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent)),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(painter: _CompassPainter(yaw: _yaw)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scanning
                        ? 'Кадров: $_shots · медленно поворачивайся вокруг себя'
                        : 'Нажми и медленно повернись на 360°, держа телефон ровно',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: !_initialized || _busy
                    ? null
                    : (_scanning ? _stopScan : _startScan),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scanning ? Colors.redAccent : Colors.white,
                    border: Border.all(color: Colors.cyanAccent, width: 3),
                  ),
                  child: Icon(
                    _scanning ? Icons.stop : Icons.camera,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double yaw;
  _CompassPainter({required this.yaw});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final progress = (yaw.abs() / 360.0).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final angleRad = yaw * math.pi / 180 - math.pi / 2;
    final dot =
        center + Offset(math.cos(angleRad), math.sin(angleRad)) * radius;
    canvas.drawCircle(dot, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.yaw != yaw;
}

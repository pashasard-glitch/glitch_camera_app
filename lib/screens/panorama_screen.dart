import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import '../services/gallery_service.dart';
import '../services/media_service.dart';
import '../services/panorama_service.dart';
import 'panorama_viewer_screen.dart';

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
  double _yaw = 0;
  double _pitch = 0;
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
          final pitchNow = _panorama.pitch;
          _rotateForDisplay(img).then((rotated) {
            _panorama.addFrame(rotated, yawNow, pitchNow);
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
      _pitch = 0;
      _result = null;
    });
    Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!_scanning) {
        t.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _yaw = _panorama.yaw;
          _pitch = _panorama.pitch;
        });
      }
    });
  }

  Future<void> _stopScan() async {
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

  Future<void> _viewAsSphere() async {
    if (_result == null) return;
    final byteData =
        await _result!.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null || !mounted) return;
    final bytes = byteData.buffer.asUint8List();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanoramaViewerScreen(pngBytes: bytes),
      ),
    );
  }

  void _discard() {
    setState(() => _result = null);
  }

  @override
  void dispose() {
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
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _viewAsSphere,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.threesixty, color: Colors.black),
                  label: const Text('Смотреть как сферу (как в VR)',
                      style: TextStyle(color: Colors.black)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _discard,
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      label: const Text('Заново',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, color: Colors.cyanAccent),
                      label: const Text('Сохранить файл',
                          style: TextStyle(color: Colors.cyanAccent)),
                    ),
                  ],
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
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _SkyMapPainter(yaw: _yaw, pitch: _pitch),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scanning
                        ? 'Кадров: $_shots · крутись по кругу и наклоняй телефон вверх/вниз'
                        : 'Нажми, медленно повернись на 360° и наклони телефон вверх и вниз',
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

/// Прямоугольная "карта неба": по горизонтали — поворот 0-360°,
/// по вертикали — наклон -90..+90°. Точка показывает, где сейчас целится
/// камера, чтобы было видно, что верх/низ ещё не отсняты.
class _SkyMapPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  _SkyMapPainter({required this.yaw, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.2)
        ..strokeWidth = 1,
    );

    var yawNorm = yaw % 360.0;
    if (yawNorm < 0) yawNorm += 360.0;
    final px = yawNorm / 360.0 * size.width;
    final py = (90.0 - pitch.clamp(-90.0, 90.0)) / 180.0 * size.height;

    canvas.drawCircle(
      Offset(px, py),
      6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyMapPainter oldDelegate) =>
      oldDelegate.yaw != yaw || oldDelegate.pitch != pitch;
}

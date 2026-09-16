import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/camera_service.dart';
import '../services/media_service.dart';
import '../services/permission_service.dart';
import '../services/shader_service.dart';
import '../widgets/effect_menu.dart';
import '../widgets/glitch_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _camera = CameraService();
  final _shader = ShaderService();
  final _media = MediaService();

  ui.Image? _frame;
  double _intensity = 0.8;
  double _time = 0.0;
  int _flags = EffectFlags.rgbSplit;
  bool _isRecording = false;
  bool _initialized = false;
  bool _permissionsAsked = false;
  int _rotationDegrees = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() => _time += 0.033);
    });
  }

  Future<void> _bootstrap() async {
    try {
      final ok = await PermissionService.ensureAll();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не все разрешения выданы')),
        );
      }

      await _shader.load();
      await _camera.init();
      await _camera.startStream((img) {
        if (mounted) setState(() => _frame = img);
      });
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      print('BOOTSTRAP ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка запуска: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _camera.stopStream();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    if (_permissionsAsked) return;
    _permissionsAsked = true;
    final ok = await PermissionService.ensureAll();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не все разрешения выданы')),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_frame == null || _shader.program == null) return;
    try {
      await _ensurePermissions();
      final rendered = await _shader.renderFrame(
        source: _frame!,
        intensity: _intensity,
        time: _time,
        flags: _flags,
        rotationDegrees: _rotationDegrees,
      );
      if (rendered == null) return;
      await _media.saveImage(rendered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено с поворотом $_rotationDegrees°')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка фото: $e')),
        );
      }
    }
  }

  Future<void> _toggleVideo() async {
    if (!_isRecording) {
      try {
        await _ensurePermissions();
        await _camera.stopStream();
        await _camera.controller!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка старта записи: $e')),
          );
        }
      }
    } else {
      try {
        final file = await _camera.controller!.stopVideoRecording();
        final path = await _media.videoPath();
        await file.saveTo(path);
        await _media.saveVideo(path);
        setState(() => _isRecording = false);
        await _camera.startStream((img) {
          if (mounted) setState(() => _frame = img);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Видео сохранено в галерею')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка остановки записи: $e')),
          );
        }
      }
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => EffectMenu(
          flags: _flags,
          onChanged: (flag) {
            setState(() => _flags ^= flag);
            setSheet(() {});
          },
        ),
      ),
    );
  }

  void _cycleRotation() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: !_initialized || _frame == null || _shader.program == null
                  ? const Center(child: CircularProgressIndicator())
                  : GlitchView(
                      program: _shader.program!,
                      frame: _frame!,
                      intensity: _intensity,
                      time: _time,
                      flags: _flags,
                      rotationDegrees: _rotationDegrees,
                    ),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black87,
                  child: Text(
                    'ROTATION: $_rotationDegrees°  (tap to change)',
                    style: const TextStyle(color: Colors.yellow, fontSize: 16),
                  ),
                ),
              ),
            ),
            if (_isRecording)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.red.withOpacity(0.7),
                  child: const Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _cycleRotation,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.yellow, width: 2),
                  ),
                  child: const Icon(Icons.rotate_right, color: Colors.yellow),
                ),
              ),
            ),
            Positioned(
              top: 70,
              right: 16,
              child: GestureDetector(
                onTap: _showMenu,
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
                        border:
                            Border.all(color: Colors.cyanAccent, width: 3),
                        color: Colors.black54,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.cyanAccent),
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
}

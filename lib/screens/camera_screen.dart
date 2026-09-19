import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_service.dart';
import '../services/media_service.dart';
import '../services/orientation_service.dart';
import '../services/permission_service.dart';
import '../services/shader_service.dart';
import '../services/video_encoder_service.dart';
import '../services/video_merge_service.dart';
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
  final _videoEncoder = VideoEncoderService();
  final _audioRecorder = AudioRecorderService();
  final _videoMerge = VideoMergeService();
  late final OrientationService _orientation;

  ui.Image? _frame;
  double _intensity = 0.8;
  double _time = 0.0;
  int _flags = EffectFlags.rgbSplit;
  bool _isRecording = false;
  bool _initialized = false;
  bool _permissionsAsked = false;
  int _rotationDegrees = 90;
  bool _mirror = false;
  bool _switchingCamera = false;

  bool _videoFrameBusy = false;
  int _videoRotation = 90;
  String? _videoRawPath;

  @override
  void initState() {
    super.initState();
    _orientation = OrientationService(
      onChanged: (rotation) {
        if (mounted) {
          setState(() {
            _rotationDegrees = rotation;
          });
        }
      },
    );
    _orientation.start();
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
      if (mounted) {
        setState(() {
          _rotationDegrees = _orientation.rotationDegrees;
        });
      }
      await _camera.startStream((img) {
        if (mounted) setState(() => _frame = img);
        if (_isRecording) {
          _appendVideoFrame(img);
        }
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

  Future<void> _switchCamera() async {
    if (_switchingCamera || _isRecording) return;
    if (!_camera.hasFrontCamera) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фронтальная камера не найдена')),
        );
      }
      return;
    }
    setState(() => _switchingCamera = true);
    try {
      await _camera.stopStream();
      await _camera.switchCamera();
      setState(() {
        _mirror = _camera.currentLens == CameraLensDirection.front;
      });
      await _camera.startStream((img) {
        if (mounted) setState(() => _frame = img);
        if (_isRecording) {
          _appendVideoFrame(img);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка переключения камеры: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  Future<void> _appendVideoFrame(ui.Image img) async {
    if (_videoFrameBusy || _shader.program == null) return;
    _videoFrameBusy = true;
    try {
      final rendered = await _shader.renderFrame(
        source: img,
        intensity: _intensity,
        time: _time,
        flags: _flags,
        rotationDegrees: _videoRotation,
        mirror: _mirror,
      );
      if (rendered != null) {
        final byteData =
            await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          await _videoEncoder.appendFrame(byteData.buffer.asUint8List());
        }
      }
    } catch (_) {
    } finally {
      _videoFrameBusy = false;
    }
  }

  @override
  void dispose() {
    _orientation.stop();
    _camera.stopStream();
    _camera.dispose();
    _audioRecorder.dispose();
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
        mirror: _mirror,
      );
      if (rendered == null) return;
      await _media.saveImage(rendered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Глитч-фото сохранено в галерею')),
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
        if (_frame == null) return;

        final isLandscape = _rotationDegrees == 90 || _rotationDegrees == 270;
        final w = isLandscape ? _frame!.height : _frame!.width;
        final h = isLandscape ? _frame!.width : _frame!.height;

        _videoRawPath = await _media.tempVideoNoAudioPath();
        final audioPath = await _media.tempAudioPath();
        _videoRotation = _rotationDegrees;

        await _videoEncoder.start(
          filepath: _videoRawPath!,
          width: w,
          height: h,
          fps: 24,
        );
        await _audioRecorder.start(audioPath);

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
        setState(() => _isRecording = false);
        await _videoEncoder.stop();
        final audioPath = await _audioRecorder.stop();

        final finalPath = await _media.videoPath();
        bool merged = false;
        if (audioPath != null && _videoRawPath != null) {
          merged = await _videoMerge.mergeVideoAudio(
            videoPath: _videoRawPath!,
            audioPath: audioPath,
            outputPath: finalPath,
          );
        }

        final pathToSave =
            merged ? finalPath : (_videoRawPath ?? finalPath);
        await _media.saveVideo(pathToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Глитч-видео сохранено в галерею')),
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

  void _toggleMirror() {
    setState(() => _mirror = !_mirror);
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
                  : Transform.flip(
                      flipX: _mirror,
                      child: AnimatedRotation(
                        turns: _rotationDegrees / 360.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: GlitchView(
                          program: _shader.program!,
                          frame: _frame!,
                          intensity: _intensity,
                          time: _time,
                          flags: _flags,
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
                onTap: _toggleMirror,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(
                      color: _mirror ? Colors.orangeAccent : Colors.cyanAccent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.flip,
                    color: _mirror ? Colors.orangeAccent : Colors.cyanAccent,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 70,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                  ),
                  child: _switchingCamera
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyanAccent,
                          ),
                        )
                      : const Icon(Icons.cameraswitch, color: Colors.cyanAccent),
                ),
              ),
            ),
            Positioned(
              top: 124,
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

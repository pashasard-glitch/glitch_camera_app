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
  double _time = 0.0;
  int _flags = EffectFlags.rgbSplit;
  final Map<int, double> _effectIntensities = {
    for (final e in EffectFlags.all) e.value: 0.8,
  };
  bool _isRecording = false;
  bool _initialized = false;
  bool _permissionsAsked = false;
  int _rotationDegrees = 90;
  int _manualRotationOffset = 0;
  bool _mirror = false;
  bool _switchingCamera = false;

  bool _videoFrameBusy = false;
  int _videoRotation = 90;
  String? _videoRawPath;

  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;
  Timer? _tickTimer;

  int get _effectiveRotation =>
      (_rotationDegrees + _manualRotationOffset) % 360;

  List<double> _intensityList() {
    return EffectFlags.all
        .map((e) => _effectIntensities[e.value] ?? 0.8)
        .toList();
  }

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
    _tickTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
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

  void _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);

    _camera.focusAndExposeAt(Offset(dx, dy));

    setState(() {
      _focusPoint = details.localPosition;
    });

    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _rotateManually() {
    setState(() {
      _manualRotationOffset = (_manualRotationOffset + 90) % 360;
    });
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
        effectIntensities: _intensityList(),
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
    _tickTimer?.cancel();
    _orientation.stop();
    _focusIndicatorTimer?.cancel();
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
        effectIntensities: _intensityList(),
        time: _time,
        flags: _flags,
        rotationDegrees: _effectiveRotation,
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

        final isLandscape =
            _effectiveRotation == 90 || _effectiveRotation == 270;
        final w = isLandscape ? _frame!.height : _frame!.width;
        final h = isLandscape ? _frame!.width : _frame!.height;

        _videoRawPath = await _media.tempVideoNoAudioPath();
        final audioPath = await _media.tempAudioPath();
        _videoRotation = _effectiveRotation;

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
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => EffectMenu(
          flags: _flags,
          intensities: _effectIntensities,
          onToggle: (flag) {
            setState(() => _flags ^= flag);
            setSheetState(() {});
          },
          onIntensityChanged: (flag, v) {
            setState(() => _effectIntensities[flag] = v);
            setSheetState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = _shader.program;
    final frame = _frame;
    final turns = _effectiveRotation ~/ 90;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (frame != null && program != null)
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _handleTapToFocus(d, constraints),
                child: ClipRect(
                  child: Transform.flip(
                    flipX: _mirror,
                    child: RotatedBox(
                      quarterTurns: turns,
                      child: GlitchView(
                        program: program,
                        frame: frame,
                        effectIntensities: _intensityList(),
                        time: _time,
                        flags: _flags,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: IgnorePointer(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (_isRecording)
            const SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.red,
                          letterSpacing: 3,
                        ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune,
                          color: Colors.cyanAccent, size: 30),
                      onPressed: _showMenu,
                    ),
                    IconButton(
                      icon: const Icon(Icons.screen_rotation,
                          color: Colors.cyanAccent, size: 30),
                      onPressed: _rotateManually,
                    ),
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.cyanAccent, width: 3),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.videocam,
                        color: _isRecording ? Colors.red : Colors.cyanAccent,
                        size: 34,
                      ),
                      onPressed: _toggleVideo,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch,
                          color: Colors.cyanAccent, size: 30),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

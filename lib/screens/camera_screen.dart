import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_service.dart';
import '../services/gallery_service.dart';
import '../services/media_service.dart';
import '../services/orientation_service.dart';
import '../services/permission_service.dart';
import '../services/shader_service.dart';
import '../services/video_encoder_service.dart';
import '../services/video_merge_service.dart';
import '../widgets/effect_menu.dart';
import '../widgets/glitch_view.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _camera = CameraService();
  final _shader = ShaderService();
  final _media = MediaService();
  final _gallery = GalleryService();
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
  bool _switchingCamera = false;

  // Положение телефона: 0 / 90 / 180 / 270 против часовой от вертикали.
  int _deviceRotation = 0;

  // true: фото и видео ровные по положению телефона.
  // false: фото и видео всегда вертикальные.
  bool _autoOrientation = true;

  // Режим зеркала: 0 = авто (по камере), 1 = всегда вкл, 2 = всегда выкл.
  int _mirrorMode = 0;

  bool _videoFrameBusy = false;
  int _videoRotation = 90;
  String? _videoRawPath;

  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;
  Timer? _tickTimer;

  bool get _mirror {
    switch (_mirrorMode) {
      case 1:
        return true;
      case 2:
        return false;
      default:
        return _camera.currentLens == CameraLensDirection.front;
    }
  }

  // Поворот для сохраняемых фото и видео.
  int get _fileRotation =>
      _camera.imageRotation(_autoOrientation ? _deviceRotation : 0);

  List<double> _intensityList() {
    return EffectFlags.all
        .map((e) => _effectIntensities[e.value] ?? 0.8)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Интерфейс всегда вертикальный: превью работает как видоискатель,
    // а положение телефона учитывается только для файлов.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _orientation = OrientationService(
      onChanged: (rotation) {
        if (mounted) setState(() => _deviceRotation = rotation);
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
        setState(() => _deviceRotation = _orientation.deviceRotation);
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

  void _toast(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1400),
      ),
    );
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

  void _toggleAutoOrientation() {
    setState(() => _autoOrientation = !_autoOrientation);
    _toast(
      _autoOrientation
          ? 'Автоповорот: вкл (фото и видео по положению телефона)'
          : 'Автоповорот: выкл (всегда вертикально)',
    );
  }

  void _cycleMirror() {
    setState(() {
      _mirrorMode = (_mirrorMode + 1) % 3;
    });
    switch (_mirrorMode) {
      case 0:
        _toast('Зеркало: авто (фронталка)');
        break;
      case 1:
        _toast('Зеркало: вкл');
        break;
      default:
        _toast('Зеркало: выкл');
    }
  }

  void _openGallery() {
    if (_isRecording) {
      _toast('Сначала останови запись');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    );
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
      if (mounted) setState(() {});
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
        rotationDegrees: _fileRotation,
        mirror: _mirror,
      );
      if (rendered == null) return;
      try {
        await _gallery.savePhoto(rendered);
      } catch (_) {}
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

        final rotation = _fileRotation;
        final isLandscape = rotation == 90 || rotation == 270;
        final w = isLandscape ? _frame!.height : _frame!.width;
        final h = isLandscape ? _frame!.width : _frame!.height;

        _videoRawPath = await _media.tempVideoNoAudioPath();
        final audioPath = await _media.tempAudioPath();
        _videoRotation = rotation;

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
        try {
          await _gallery.saveVideo(pathToSave);
        } catch (_) {}
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      elevation: 0,
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
    // Превью: поворот кадра определяется только датчиком камеры.
    final previewTurns = (_camera.sensorOrientation ~/ 90) % 4;
    final mirror = _mirror;

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
                    flipX: mirror,
                    child: RotatedBox(
                      quarterTurns: previewTurns,
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
          // Кнопки справа сверху: автоповорот, зеркало, плеер.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Автоповорот',
                      icon: Icon(
                        Icons.screen_lock_rotation,
                        color: _autoOrientation
                            ? Colors.cyanAccent
                            : Colors.grey,
                        size: 30,
                      ),
                      onPressed: _toggleAutoOrientation,
                    ),
                    IconButton(
                      tooltip: 'Зеркало',
                      icon: Icon(
                        Icons.flip,
                        color: _mirrorMode == 2
                            ? Colors.grey
                            : Colors.cyanAccent,
                        size: 30,
                      ),
                      onPressed: _cycleMirror,
                    ),
                    IconButton(
                      tooltip: 'Плеер',
                      icon: const Icon(
                        Icons.photo_library,
                        color: Colors.cyanAccent,
                        size: 30,
                      ),
                      onPressed: _openGallery,
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

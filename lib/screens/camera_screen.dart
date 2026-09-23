import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/tracker_config.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_service.dart';
import '../services/gallery_service.dart';
import '../services/media_service.dart';
import '../services/orientation_service.dart';
import '../services/permission_service.dart';
import '../services/shader_service.dart';
import '../services/tracking_renderer.dart';
import '../services/video_encoder_service.dart';
import '../services/video_merge_service.dart';
import '../widgets/effect_menu.dart';
import '../widgets/glitch_view.dart';
import '../widgets/settings_menu.dart';
import '../widgets/tracking_overlay.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const int _videoFps = 24;
  static const int _maxRepeat = 96;

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
  bool _trackingEnabled = false;

  List<TrackerConfig> _trackerConfigs = TrackerConfig.defaults();
  TrackingMode _trackingMode = TrackingMode.random;
  double _trackingVisibleDuration = 0.6;
  Color _trackingColor = Colors.cyanAccent;
  bool _trackingWebEnabled = false;

  int _deviceRotation = 0;
  bool _autoOrientation = true;
  int _mirrorMode = 0;

  double _videoSpeed = 1.0;
  double _recSpeed = 1.0;
  bool _recWithAudio = true;
  final Stopwatch _recClock = Stopwatch();
  int _emittedFrames = 0;

  bool _videoFrameBusy = false;
  int _videoRotation = 90;
  String? _videoRawPath;

  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;
  Timer? _tickTimer;

  // Зум.
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  Offset? _scaleStartFocal;
  bool _didPinch = false;
  bool _pinchActive = false;

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

  int get _fileRotation =>
      _camera.imageRotation(_autoOrientation ? _deviceRotation : 0);

  List<double> _intensityList() {
    return EffectFlags.all
        .map((e) => _effectIntensities[e.value] ?? 0.8)
        .toList();
  }

  void Function(Canvas canvas, double width, double height)?
      get _trackingOverlayFn {
    if (!_trackingEnabled) return null;
    return (canvas, w, h) => TrackingRenderer.paint(
          canvas,
          Size(w, h),
          _time,
          _trackerConfigs,
          _trackingMode,
          _trackingVisibleDuration,
          _trackingColor,
          _trackingWebEnabled,
        );
  }

  @override
  void initState() {
    super.initState();
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
        setState(() {
          _deviceRotation = _orientation.deviceRotation;
          _minZoom = _camera.minZoom;
          _maxZoom = _camera.maxZoom;
          _zoom = _minZoom;
        });
      }
      await _camera.setZoom(_zoom);
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

  void _focusAt(Offset localPosition, BoxConstraints constraints) {
    final size = Size(constraints.maxWidth, constraints.maxHeight);
    final dx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / size.height).clamp(0.0, 1.0);

    _camera.focusAndExposeAt(Offset(dx, dy));

    setState(() => _focusPoint = localPosition);

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
    setState(() => _mirrorMode = (_mirrorMode + 1) % 3);
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

  void _toggleTracking() {
    setState(() => _trackingEnabled = !_trackingEnabled);
    _toast(_trackingEnabled ? 'Трекинг: вкл' : 'Трекинг: выкл');
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
      if (mounted) {
        setState(() {
          _minZoom = _camera.minZoom;
          _maxZoom = _camera.maxZoom;
          _zoom = _minZoom;
        });
      }
      await _camera.setZoom(_zoom);
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

    final seconds = _recClock.elapsedMicroseconds / 1000000.0;
    final target = (seconds * _videoFps / _recSpeed).floor() + 1;
    var repeat = target - _emittedFrames;
    if (repeat <= 0) return;
    if (repeat > _maxRepeat) repeat = _maxRepeat;

    _videoFrameBusy = true;
    try {
      final rendered = await _shader.renderFrame(
        source: img,
        effectIntensities: _intensityList(),
        time: _time,
        flags: _flags,
        rotationDegrees: _videoRotation,
        mirror: _mirror,
        overlay: _trackingOverlayFn,
      );
      if (rendered != null) {
        final byteData =
            await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          for (int i = 0; i < repeat; i++) {
            if (!_isRecording) break;
            await _videoEncoder.appendFrame(bytes);
            _emittedFrames++;
          }
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
        overlay: _trackingOverlayFn,
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
        _videoRotation = rotation;
        _recSpeed = _videoSpeed;
        _recWithAudio = (_recSpeed - 1.0).abs() < 0.001;

        await _videoEncoder.start(
          filepath: _videoRawPath!,
          width: w,
          height: h,
          fps: _videoFps,
        );
        if (_recWithAudio) {
          final audioPath = await _media.tempAudioPath();
          await _audioRecorder.start(audioPath);
        }

        _emittedFrames = 0;
        _recClock
          ..reset()
          ..start();
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
        _recClock.stop();

        for (int i = 0; i < 50 && _videoFrameBusy; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await _videoEncoder.stop();
        final audioPath = _recWithAudio ? await _audioRecorder.stop() : null;

        final finalPath = await _media.videoPath();
        bool merged = false;
        if (audioPath != null && _videoRawPath != null) {
          merged = await _videoMerge.mergeVideoAudio(
            videoPath: _videoRawPath!,
            audioPath: audioPath,
            outputPath: finalPath,
          );
        }

        final pathToSave = merged ? finalPath : (_videoRawPath ?? finalPath);
        try {
          await _gallery.saveVideo(pathToSave);
        } catch (_) {}
        await _media.saveVideo(pathToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _recWithAudio
                    ? 'Глитч-видео сохранено в галерею'
                    : 'Глитч-видео сохранено в галерею (без звука)',
              ),
            ),
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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SettingsMenu(
          videoSpeed: _videoSpeed,
          onVideoSpeedChanged: (v) => _videoSpeed = v,
          trackerConfigs: _trackerConfigs,
          trackingMode: _trackingMode,
          trackingVisibleDuration: _trackingVisibleDuration,
          trackingColor: _trackingColor,
          trackingWebEnabled: _trackingWebEnabled,
          onTrackerConfigsChanged: (list) =>
              setState(() => _trackerConfigs = list),
          onTrackingModeChanged: (m) => setState(() => _trackingMode = m),
          onTrackingVisibleDurationChanged: (v) =>
              setState(() => _trackingVisibleDuration = v),
          onTrackingColorChanged: (c) => setState(() => _trackingColor = c),
          onTrackingWebEnabledChanged: (v) =>
              setState(() => _trackingWebEnabled = v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final program = _shader.program;
    final frame = _frame;
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
                onScaleStart: (details) {
                  _scaleStartFocal = details.localFocalPoint;
                  _baseZoom = _zoom;
                  _didPinch = false;
                  setState(() => _pinchActive = true);
                },
                onScaleUpdate: (details) {
                  if ((details.scale - 1.0).abs() > 0.02) {
                    _didPinch = true;
                    final z =
                        (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
                    if ((z - _zoom).abs() > 0.005) {
                      _zoom = z;
                      _camera.setZoom(z);
                      setState(() {});
                    }
                  }
                },
                onScaleEnd: (details) {
                  if (!_didPinch && _scaleStartFocal != null) {
                    _focusAt(_scaleStartFocal!, constraints);
                  }
                  _scaleStartFocal = null;
                  setState(() => _pinchActive = false);
                },
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
          if (_trackingEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: TrackingOverlay(
                  configs: _trackerConfigs,
                  mode: _trackingMode,
                  visibleDuration: _trackingVisibleDuration,
                  time: _time,
                  color: _trackingColor,
                  webEnabled: _trackingWebEnabled,
                ),
              ),
            ),
          if (_pinchActive && _maxZoom > _minZoom)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                        color: Colors.cyanAccent, fontSize: 16),
                  ),
                ),
              ),
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
                        style: TextStyle(color: Colors.red, letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                        color:
                            _autoOrientation ? Colors.cyanAccent : Colors.grey,
                        size: 30,
                      ),
                      onPressed: _toggleAutoOrientation,
                    ),
                    IconButton(
                      tooltip: 'Зеркало',
                      icon: Icon(
                        Icons.flip,
                        color:
                            _mirrorMode == 2 ? Colors.grey : Colors.cyanAccent,
                        size: 30,
                      ),
                      onPressed: _cycleMirror,
                    ),
                    IconButton(
                      tooltip: 'Трекинг',
                      icon: Icon(
                        Icons.gps_fixed,
                        color: _trackingEnabled
                            ? Colors.cyanAccent
                            : Colors.grey,
                        size: 30,
                      ),
                      onPressed: _toggleTracking,
                    ),
                    IconButton(
                      tooltip: 'Плеер',
                      icon: const Icon(Icons.photo_library,
                          color: Colors.cyanAccent, size: 30),
                      onPressed: _openGallery,
                    ),
                    IconButton(
                      tooltip: 'Настройки',
                      icon: const Icon(Icons.settings,
                          color: Colors.cyanAccent, size: 30),
                      onPressed: _showSettings,
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
                          border:
                              Border.all(color: Colors.cyanAccent, width: 3),
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

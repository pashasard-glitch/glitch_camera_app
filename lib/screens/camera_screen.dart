import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/camera_service.dart';
import '../services/media_service.dart';
import '../services/orientation_service.dart';
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
  late final OrientationService _orientation;

  ui.Image? _frame;
  double _intensity = 0.8;
  double _time = 0.0;
  int _flags = EffectFlags.rgbSplit;
  bool _isRecording = false;
  bool _initialized = false;
  bool _permissionsAsked = false;
  int _rotationDegrees = 90;

  @override
  void initState() {
    super.initState();
    _orientation = OrientationService(
      onChanged: (deviceRotation) {
        if (mounted) {
          setState(() {
            _rotationDegrees = _computeRotation(deviceRotation);
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

  int _computeRotation(int deviceRotation) {
    final sensorOrientation = _camera.sensorOrientation;
    return (sensorOrientation - deviceRotation + 360) % 360;
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
          _rotationDegrees = _computeRotation(_orientation.rotation);
        });
      }
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
    _orientation.stop();
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
    print('TAKE PHOTO CALLED');
    if (_frame == null || _shader.program == null) {
      print('PHOTO: frame or shader is null');
      return;
    }
    try {
      await _ensurePermissions();
      final rendered = await _shader.renderFrame(
        source: _frame!,
        intensity: _intensity,
        time: _time,
        flags: _flags,
        rotationDegrees: _rotationDegrees,
      );
      if (rendered == null) {
        print('PHOTO: renderFrame returned null');
        return;
      }
      await _media.saveImage(rendered);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Глитч-фото сохранено в галерею')),
        );
      }
    } catch (e) {
      print('PHOTO ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка фото: $e')),
        );
      }
    }
  }

  Future<void> _toggleVideo() async {
    print('TOGGLE VIDEO CALLED, recording=$_isRecording');
    if (!_isRecording) {
      try {
        await _ensurePermissions();
        await _camera.stopStream();
        await _camera.controller!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        print('VIDEO START ERROR: $e');
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
        print('VIDEO STOP ERROR: $e');
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
                      int

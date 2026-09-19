.import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;
  bool _busy = false;
  int sensorOrientation = 90;
  List<CameraDescription> _cameras = [];
  CameraLensDirection currentLens = CameraLensDirection.back;

  bool get hasFrontCamera =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front);

  Future<void> init() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == currentLens,
      orElse: () => _cameras.first,
    );

    await _initController(camera);
  }

  Future<void> switchCamera() async {
    if (_cameras.isEmpty) return;
    final nextLens = currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == nextLens,
      orElse: () => _cameras.first,
    );

    await controller?.dispose();
    await _initController(camera);
  }

  Future<void> _initController(CameraDescription camera) async {
    currentLens = camera.lensDirection;
    sensorOrientation = camera.sensorOrientation;

    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller!.initialize();
  }

  Future<void> startStream(
    void Function(ui.Image frame) onFrame,
  ) async {
    if (controller == null) return;
    await controller!.startImageStream((CameraImage image) async {
      if (_busy) return;
      _busy = true;
      try {
        final uiImage = await _convertYUV(image);
        onFrame(uiImage);
      } catch (_) {}
      _busy = false;
    });
  }

  Future<void> stopStream() async {
    if (controller == null) return;
    try {
      await controller!.stopImageStream();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
  }

  Future<ui.Image> _convertYUV(CameraImage image) async {
    final width = image.width;
    final height = image.height;
    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final uvRowStride = planeU.bytesPerRow;
    final uvPixelStride = planeU.bytesPerPixel ?? 1;

    final rgb = Uint8List(width * height * 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * planeY.bytesPerRow + x;
        final uvIndex =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final Y = planeY.bytes[yIndex];
        final U = planeU.bytes[uvIndex] - 128;
        final V = planeV.bytes[uvIndex] - 128;

        final r = (Y + 1.402 * V).round().clamp(0, 255);
        final g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        final b = (Y + 1.772 * U).round().clamp(0, 255);

        final idx = (y * width + x) * 4;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
        rgb[idx + 3] = 255;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgb,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }
}

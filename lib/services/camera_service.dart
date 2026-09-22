import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;

class _YuvFrame {
  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  _YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });
}

Uint8List _yuvToRgba(_YuvFrame f) {
  final w = f.width;
  final h = f.height;
  final out = Uint8List(w * h * 4);
  int o = 0;

  for (int yy = 0; yy < h; yy++) {
    final yRow = yy * f.yRowStride;
    final uvRow = (yy >> 1) * f.uvRowStride;
    for (int xx = 0; xx < w; xx++) {
      final yv = f.y[yRow + xx];
      final uvIndex = uvRow + (xx >> 1) * f.uvPixelStride;
      final u = f.u[uvIndex] - 128;
      final v = f.v[uvIndex] - 128;

      int r = yv + ((91881 * v) >> 16);
      int g = yv - ((22554 * u + 46802 * v) >> 16);
      int b = yv + ((116130 * u) >> 16);

      out[o++] = r < 0 ? 0 : (r > 255 ? 255 : r);
      out[o++] = g < 0 ? 0 : (g > 255 ? 255 : g);
      out[o++] = b < 0 ? 0 : (b > 255 ? 255 : b);
      out[o++] = 255;
    }
  }
  return out;
}

class CameraService {
  CameraController? controller;
  bool _busy = false;
  int sensorOrientation = 90;
  List<CameraDescription> _cameras = [];
  CameraLensDirection currentLens = CameraLensDirection.back;
  double minZoom = 1.0;
  double maxZoom = 1.0;

  bool get hasFrontCamera =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front);

  int imageRotation(int deviceRotation) {
    if (currentLens == CameraLensDirection.front) {
      return (sensorOrientation + deviceRotation) % 360;
    }
    return (sensorOrientation - deviceRotation + 360) % 360;
  }

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
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller!.initialize();
    try {
      await controller!.setFocusMode(FocusMode.auto);
      await controller!.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    try {
      minZoom = await controller!.getMinZoomLevel();
      maxZoom = await controller!.getMaxZoomLevel();
    } catch (_) {
      minZoom = 1.0;
      maxZoom = 1.0;
    }
  }

  Future<void> setZoom(double zoom) async {
    if (controller == null) return;
    try {
      await controller!.setZoomLevel(zoom.clamp(minZoom, maxZoom));
    } catch (_) {}
  }

  Future<void> focusAndExposeAt(ui.Offset normalizedPoint) async {
    if (controller == null) return;
    try {
      await controller!.setFocusPoint(normalizedPoint);
      await controller!.setExposurePoint(normalizedPoint);
    } catch (_) {}
  }

  Future<void> startStream(void Function(ui.Image frame) onFrame) async {
    if (controller == null) return;
    await controller!.startImageStream((CameraImage image) async {
      if (_busy) return;
      _busy = true;
      try {
        final uiImage = await _convertYUV(image);
        onFrame(uiImage);
      } catch (_) {
      } finally {
        _busy = false;
      }
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

    final rgba = await compute(
      _yuvToRgba,
      _YuvFrame(
        width: width,
        height: height,
        y: planeY.bytes,
        u: planeU.bytes,
        v: planeV.bytes,
        yRowStride: planeY.bytesPerRow,
        uvRowStride: planeU.bytesPerRow,
        uvPixelStride: planeU.bytesPerPixel ?? 1,
      ),
    );

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }
}

import 'dart:typed_data';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

class VideoEncoderService {
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<void> start({
    required String filepath,
    required int width,
    required int height,
    int fps = 24,
  }) async {
    await FlutterQuickVideoEncoder.setup(
      width: width,
      height: height,
      fps: fps,
      videoBitrate: 4 * 1000 * 1000,
      audioBitrate: 0,
      audioChannels: 0,
      sampleRate: 0,
      profileLevel: VideoProfileLevel.any,
      filepath: filepath,
    );
    _isRecording = true;
  }

  Future<void> appendFrame(Uint8List rgbaBytes) async {
    if (!_isRecording) return;
    try {
      await FlutterQuickVideoEncoder.appendVideoFrame(rgbaBytes);
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_isRecording) return;
    await FlutterQuickVideoEncoder.finish();
    _isRecording = false;
  }
}

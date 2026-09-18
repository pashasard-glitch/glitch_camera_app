import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> start(String filepath) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filepath,
    );
  }

  Future<String?> stop() async {
    return await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

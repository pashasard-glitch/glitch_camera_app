import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';

class VideoMergeService {
  Future<bool> mergeVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final session = await FFmpegKit.execute(
      '-y -i "$videoPath" -i "$audioPath" -c:v copy -c:a aac -shortest "$outputPath"',
    );
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }
}

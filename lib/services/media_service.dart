import 'dart:io';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class MediaService {
  Future<void> saveImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/glitch_${DateTime.now().millisecondsSinceEpoch}.png';

    await File(path).writeAsBytes(byteData.buffer.asUint8List());
    await Gal.putImage(path);
  }

  Future<void> saveVideo(String path) async {
    await Gal.putVideo(path);
  }

  Future<String> videoPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/glitch_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }
}

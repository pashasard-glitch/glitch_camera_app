import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

class GalleryItem {
  final File file;
  final bool isVideo;
  final DateTime date;

  GalleryItem(this.file, this.isVideo, this.date);
}

class GalleryService {
  static const _videoExt = {'mp4', 'mov', 'm4v', 'webm', 'mkv'};
  static const _photoExt = {'png', 'jpg', 'jpeg'};

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/glitch_gallery');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _stamp() => DateTime.now().millisecondsSinceEpoch.toString();

  String _ext(String path) {
    final name = path.split('/').last;
    final i = name.lastIndexOf('.');
    return i == -1 ? '' : name.substring(i + 1).toLowerCase();
  }

  Future<void> savePhoto(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = await _dir();
    await File('${dir.path}/IMG_${_stamp()}.png')
        .writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  Future<void> saveVideo(String sourcePath) async {
    final dir = await _dir();
    var ext = _ext(sourcePath);
    if (!_videoExt.contains(ext)) ext = 'mp4';
    await File(sourcePath).copy('${dir.path}/VID_${_stamp()}.$ext');
  }

  Future<List<GalleryItem>> list() async {
    final dir = await _dir();
    final items = <GalleryItem>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final ext = _ext(e.path);
      final isVideo = _videoExt.contains(ext);
      final isPhoto = _photoExt.contains(ext);
      if (!isVideo && !isPhoto) continue;
      items.add(GalleryItem(e, isVideo, await e.lastModified()));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> delete(GalleryItem item) async {
    if (await item.file.exists()) {
      await item.file.delete();
    }
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:panorama_image/panorama_image.dart';

class PanoramaViewerScreen extends StatelessWidget {
  final Uint8List pngBytes;

  const PanoramaViewerScreen({super.key, required this.pngBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: const Text('ПРОСМОТР ПАНОРАМЫ',
            style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
      ),
      body: PanoramaViewer(
        image: MemoryImage(pngBytes),
        initialFOV: 90.0,
      ),
    );
  }
}

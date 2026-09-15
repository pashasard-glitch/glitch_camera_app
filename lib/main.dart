import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlitchCameraApp());
}

class GlitchCameraApp extends StatelessWidget {
  const GlitchCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glitch Camera',
      theme: ThemeData.dark(),
      home: const CameraScreen(),
    );
  }
}

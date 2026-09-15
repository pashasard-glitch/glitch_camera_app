import 'package:flutter/material.dart';

void main() {
  runApp(const GlitchCameraApp());
}

class GlitchCameraApp extends StatelessWidget {
  const GlitchCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glitch Camera',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glitch Camera')),
      body: const Center(
        child: Text('Здесь будет камера и глитч-эффекты'),
      ),
    );
  }
}

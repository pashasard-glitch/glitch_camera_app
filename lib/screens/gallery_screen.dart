import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/gallery_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _service = GalleryService();
  List<GalleryItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.list();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _open(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ViewerScreen(
          items: _items!,
          initialIndex: index,
          service: _service,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: const Text(
          'GALLERY',
          style: TextStyle(color: Colors.cyanAccent, letterSpacing: 6),
        ),
      ),
      body: items == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          : items.isEmpty
              ? const Center(
                  child: Text(
                    'Пока пусто',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _Tile(
                    item: items[i],
                    onTap: () => _open(i),
                  ),
                ),
    );
  }
}

class _Tile extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback onTap;

  const _Tile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: item.isVideo
          ? Container(
              color: const Color(0xFF111111),
              child: const Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.cyanAccent,
                      size: 44,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Icon(Icons.videocam,
                        color: Colors.cyanAccent, size: 16),
                  ),
                ],
              ),
            )
          : Image.file(
              item.file,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF111111),
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
    );
  }
}

class _ViewerScreen extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  final GalleryService service;

  const _ViewerScreen({
    required this.items,
    required this.initialIndex,
    required this.service,
  });

  @override
  State<_ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<_ViewerScreen> {
  late final List<GalleryItem> _items = List.of(widget.items);
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Удалить?',
            style: TextStyle(color: Colors.cyanAccent)),
        content: const Text(
          'Файл удалится из плеера. Копия в системной галерее останется.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final item = _items[_index];
    await widget.service.delete(item);
    if (!mounted) return;

    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
    if (_items.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: Text(
          _items.isEmpty ? '' : '${_index + 1} / ${_items.length}',
          style: const TextStyle(color: Colors.cyanAccent, letterSpacing: 3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _items.isEmpty ? null : _delete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final item = _items[i];
          if (item.isVideo) {
            return _VideoPage(
              key: ValueKey(item.file.path),
              file: item.file,
            );
          }
          return InteractiveViewer(
            key: ValueKey(item.file.path),
            minScale: 1,
            maxScale: 5,
            child: Center(child: Image.file(item.file)),
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final File file;

  const _VideoPage({super.key, required this.file});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(widget.file);
    _init();
  }

  Future<void> _init() async {
    try {
      await _c.initialize();
      await _c.setLooping(true);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_c.value.isPlaying) {
      _c.pause();
    } else {
      _c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Не удалось открыть видео',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _c.value.aspectRatio,
                      child: VideoPlayer(_c),
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _c,
                      builder: (_, v, __) => v.isPlaying
                          ? const SizedBox.shrink()
                          : const Icon(
                              Icons.play_circle_fill,
                              size: 72,
                              color: Colors.cyanAccent,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: VideoProgressIndicator(
              _c,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 10),
              colors: const VideoProgressColors(
                playedColor: Colors.cyanAccent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

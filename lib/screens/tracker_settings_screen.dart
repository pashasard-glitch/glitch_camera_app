import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tracker_config.dart';

class TrackerSettingsScreen extends StatefulWidget {
  final List<TrackerConfig> configs;
  final TrackingMode mode;
  final double visibleDuration;
  final Color color;
  final bool webEnabled;
  final ValueChanged<List<TrackerConfig>> onConfigsChanged;
  final ValueChanged<TrackingMode> onModeChanged;
  final ValueChanged<double> onVisibleDurationChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<bool> onWebEnabledChanged;

  const TrackerSettingsScreen({
    super.key,
    required this.configs,
    required this.mode,
    required this.visibleDuration,
    required this.color,
    required this.webEnabled,
    required this.onConfigsChanged,
    required this.onModeChanged,
    required this.onVisibleDurationChanged,
    required this.onColorChanged,
    required this.onWebEnabledChanged,
  });

  @override
  State<TrackerSettingsScreen> createState() => _TrackerSettingsScreenState();
}

class _TrackerSettingsScreenState extends State<TrackerSettingsScreen> {
  late List<TrackerConfig> _configs = List.of(widget.configs);
  late TrackingMode _mode = widget.mode;
  late double _duration = widget.visibleDuration;
  late Color _color = widget.color;
  late bool _webEnabled = widget.webEnabled;
  late final TextEditingController _hexCtrl =
      TextEditingController(text: _toHex(_color));
  int _nextId = 0;

  void _emitConfigs() => widget.onConfigsChanged(List.of(_configs));

  static String _toHex(Color c) {
    return '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color? _parseHex(String input) {
    var s = input.trim().replaceAll('#', '');
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _applyColor(Color c) {
    setState(() {
      _color = c;
      _hexCtrl.text = _toHex(c);
    });
    widget.onColorChanged(c);
  }

  void _onHexSubmitted(String v) {
    final c = _parseHex(v);
    if (c != null) _applyColor(c);
  }

  void _onChannelChanged({int? r, int? g, int? b}) {
    _applyColor(Color.fromARGB(
      255,
      r ?? _color.red,
      g ?? _color.green,
      b ?? _color.blue,
    ));
  }

  Future<void> _addTracker() async {
    final nameCtrl = TextEditingController(text: 'OBJECT');
    final sizeCtrl = TextEditingController(text: '15');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Новый трекер',
            style: TextStyle(color: Colors.cyanAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Имя',
                labelStyle: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            TextField(
              controller: sizeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Размер, % (5–40)',
                labelStyle: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить',
                style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
    if (result != true) return;

    final name = nameCtrl.text.trim().isEmpty
        ? 'OBJECT'
        : nameCtrl.text.trim().toUpperCase();
    final sizePct = (int.tryParse(sizeCtrl.text.trim()) ?? 15).clamp(5, 40);

    setState(() {
      _configs.add(TrackerConfig(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}',
        label: name,
        sizeFrac: sizePct / 100,
      ));
    });
    _emitConfigs();
  }

  Future<void> _fillDense() async {
    final countCtrl = TextEditingController(text: '18');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Плотный набор',
            style: TextStyle(color: Colors.cyanAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Добавит сразу N мелких трекеров без имени — '
              'только короткий номер, как у сканера.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Количество (1–60)',
                labelStyle: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить',
                style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
    if (result != true) return;

    final count = (int.tryParse(countCtrl.text.trim()) ?? 18).clamp(1, 60);
    setState(() {
      for (int i = 0; i < count; i++) {
        _configs.add(TrackerConfig(
          id: 'dense_${DateTime.now().microsecondsSinceEpoch}_${_nextId++}',
          label: '',
          sizeFrac: 0.05,
        ));
      }
    });
    _emitConfigs();
  }

  void _removeTracker(int index) {
    setState(() => _configs.removeAt(index));
    _emitConfigs();
  }

  void _renameTracker(int index, String value) {
    final v =
        value.trim().isEmpty ? _configs[index].label : value.trim().toUpperCase();
    setState(() => _configs[index] = _configs[index].copyWith(label: v));
    _emitConfigs();
  }

  void _resizeTracker(int index, String value) {
    final current = (_configs[index].sizeFrac * 100).round();
    final pct = (int.tryParse(value.trim()) ?? current).clamp(5, 40);
    setState(
        () => _configs[index] = _configs[index].copyWith(sizeFrac: pct / 100));
    _emitConfigs();
  }

  void _toggleRandomTag(int index, bool value) {
    setState(
        () => _configs[index] = _configs[index].copyWith(randomTag: value));
    _emitConfigs();
  }

  void _clearAll() {
    setState(() => _configs.clear());
    _emitConfigs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: const Text('ДОБАВИТЬ ТРЕКЕР',
            style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Плотный набор',
            icon: const Icon(Icons.grid_on, color: Colors.cyanAccent),
            onPressed: _fillDense,
          ),
          IconButton(
            tooltip: 'Очистить всё',
            icon: const Icon(Icons.clear_all, color: Colors.redAccent),
            onPressed: _configs.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        onPressed: _addTracker,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text('РЕЖИМ',
              style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _modeChip('Обычный', TrackingMode.random),
              _modeChip('Сетка', TrackingMode.grid),
              _modeChip('Фокус', TrackingMode.focus),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'ВРЕМЯ ПОКАЗА: ${_duration.toStringAsFixed(1)} с'
            '${_mode != TrackingMode.random ? ' (не влияет в этом режиме)' : ''}',
            style: const TextStyle(color: Colors.cyanAccent, letterSpacing: 1),
          ),
          Slider(
            value: _duration,
            min: 0.2,
            max: 3.0,
            activeColor: Colors.cyanAccent,
            inactiveColor: Colors.grey.withOpacity(0.3),
            onChanged: (v) {
              setState(() => _duration = v);
              widget.onVisibleDurationChanged(v);
            },
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _webEnabled,
            onChanged: (v) {
              setState(() => _webEnabled = v ?? false);
              widget.onWebEnabledChanged(_webEnabled);
            },
            activeColor: Colors.cyanAccent,
            checkColor: Colors.black,
            title: const Text(
              'Соединять линиями (паутина)',
              style: TextStyle(color: Colors.cyanAccent),
            ),
            subtitle: const Text(
              'Линии между ближайшими трекерами, включая именованные',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('ЦВЕТ ТРЕКЕРОВ',
                  style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hexCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
              LengthLimitingTextInputFormatter(7),
            ],
            style: const TextStyle(color: Colors.white, letterSpacing: 1),
            cursorColor: Colors.cyanAccent,
            decoration: InputDecoration(
              labelText: 'HEX, например #00FF88',
              labelStyle: const TextStyle(color: Colors.cyanAccent),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
            ),
            onSubmitted: _onHexSubmitted,
          ),
          const SizedBox(height: 12),
          _channelSlider('R', _color.red, Colors.redAccent,
              (v) => _onChannelChanged(r: v)),
          _channelSlider('G', _color.green, Colors.greenAccent,
              (v) => _onChannelChanged(g: v)),
          _channelSlider('B', _color.blue, Colors.lightBlueAccent,
              (v) => _onChannelChanged(b: v)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('ТРЕКЕРЫ',
                  style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
              const Spacer(),
              Text('${_configs.length} шт.',
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _configs.length; i++) _trackerCard(i),
          if (_configs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Нет трекеров — добавь через + или плотный набор',
                  style: TextStyle(color: Colors.white54)),
            ),
        ],
      ),
    );
  }

  Widget _channelSlider(
      String label, int value, Color trackColor, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(color: trackColor, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: trackColor,
            inactiveColor: trackColor.withOpacity(0.2),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _modeChip(String label, TrackingMode value) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: Colors.cyanAccent,
      backgroundColor: Colors.black,
      side: const BorderSide(color: Colors.cyanAccent),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.cyanAccent),
      onSelected: (_) {
        setState(() => _mode = value);
        widget.onModeChanged(value);
      },
    );
  }

  Widget _trackerCard(int index) {
    final c = _configs[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('name_${c.id}'),
                  initialValue: c.label,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Имя (пусто = только номер)',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                  ),
                  onFieldSubmitted: (v) => _renameTracker(index, v),
                  onChanged: (v) => _renameTracker(index, v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextFormField(
                  key: ValueKey('size_${c.id}'),
                  initialValue: (c.sizeFrac * 100).round().toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '%',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                  ),
                  onFieldSubmitted: (v) => _resizeTracker(index, v),
                  onChanged: (v) => _resizeTracker(index, v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeTracker(index),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: c.randomTag,
            onChanged: (v) => _toggleRandomTag(index, v ?? false),
            activeColor: Colors.cyanAccent,
            checkColor: Colors.black,
            title: const Text(
              'Случайные символы (быстро меняются)',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

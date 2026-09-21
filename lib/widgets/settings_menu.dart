import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsMenu extends StatefulWidget {
  final double videoSpeed;
  final ValueChanged<double> onVideoSpeedChanged;

  const SettingsMenu({
    super.key,
    required this.videoSpeed,
    required this.onVideoSpeedChanged,
  });

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  static const double _minSpeed = 0.5;
  static const double _maxSpeed = 8.0;
  static const List<double> _presets = [0.5, 1, 2, 3, 4];

  late double _speed = widget.videoSpeed;
  late final TextEditingController _text =
      TextEditingController(text: _fmt(widget.videoSpeed));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    var s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  double? _parse(String s) {
    return double.tryParse(s.trim().replaceAll(',', '.'));
  }

  void _apply(double v, {bool updateText = true}) {
    final clamped = v.clamp(_minSpeed, _maxSpeed).toDouble();
    setState(() => _speed = clamped);
    widget.onVideoSpeedChanged(clamped);
    if (updateText) {
      _text.value = TextEditingValue(
        text: _fmt(clamped),
        selection: TextSelection.collapsed(offset: _fmt(clamped).length),
      );
    }
  }

  void _onTyped(String s) {
    final v = _parse(s);
    if (v == null) return;
    _apply(v, updateText: false);
  }

  void _commitText() {
    final v = _parse(_text.text);
    if (v == null) {
      _apply(_speed);
    } else {
      _apply(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'СКОРОСТЬ ВИДЕО: ${_fmt(_speed)}×',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  letterSpacing: 2,
                ),
              ),
              Slider(
                value: _speed,
                min: _minSpeed,
                max: _maxSpeed,
                divisions: 15,
                activeColor: Colors.cyanAccent,
                inactiveColor: Colors.grey.withOpacity(0.3),
                onChanged: (v) => _apply(v),
              ),
              Wrap(
                spacing: 8,
                children: _presets.map((p) {
                  final selected = (_speed - p).abs() < 0.001;
                  return ChoiceChip(
                    label: Text('${_fmt(p)}×'),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: Colors.cyanAccent,
                    backgroundColor: Colors.black,
                    side: const BorderSide(color: Colors.cyanAccent),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.cyanAccent,
                    ),
                    onSelected: (_) => _apply(p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.cyanAccent,
                decoration: InputDecoration(
                  labelText: 'Своя скорость (0.5 – 8)',
                  labelStyle: const TextStyle(color: Colors.cyanAccent),
                  suffixText: '×',
                  suffixStyle: const TextStyle(color: Colors.cyanAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.cyanAccent.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
                onChanged: _onTyped,
                onSubmitted: (_) => _commitText(),
              ),
              const SizedBox(height: 12),
              const Text(
                '1× — обычная скорость. 2× — быстрее в два раза, '
                '0.5× — медленнее в два раза. '
                'Звук записывается только на 1×.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

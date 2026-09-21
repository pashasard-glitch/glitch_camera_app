import 'package:flutter/material.dart';

import '../constants.dart';

class EffectMenu extends StatefulWidget {
  final int flags;
  final Map<int, double> intensities;
  final ValueChanged<int> onToggle;
  final void Function(int flag, double value) onIntensityChanged;

  const EffectMenu({
    super.key,
    required this.flags,
    required this.intensities,
    required this.onToggle,
    required this.onIntensityChanged,
  });

  @override
  State<EffectMenu> createState() => _EffectMenuState();
}

class _EffectMenuState extends State<EffectMenu> {
  // Флаг эффекта, ползунок которого сейчас двигают. null = никто не двигает.
  int? _activeFlag;

  @override
  Widget build(BuildContext context) {
    final dragging = _activeFlag != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: dragging ? Colors.transparent : Colors.black.withOpacity(0.95),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: dragging ? 0.0 : 1.0,
                child: const Text(
                  'EFFECTS',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...EffectFlags.all.map((e) => _tile(e.key, e.value)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String label, int flag) {
    final on = (widget.flags & flag) != 0;
    final value = widget.intensities[flag] ?? 0.8;
    final isActive = _activeFlag == flag;
    final hidden = _activeFlag != null && !isActive;

    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: hidden ? 0.0 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.black.withOpacity(0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: on,
                onChanged: (_) => widget.onToggle(flag),
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    letterSpacing: 3,
                  ),
                ),
                activeColor: Colors.cyanAccent,
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.5,
                  activeColor: on ? Colors.cyanAccent : Colors.grey,
                  inactiveColor: Colors.grey.withOpacity(0.3),
                  onChangeStart: (_) => setState(() => _activeFlag = flag),
                  onChangeEnd: (_) => setState(() => _activeFlag = null),
                  onChanged: (v) => widget.onIntensityChanged(flag, v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

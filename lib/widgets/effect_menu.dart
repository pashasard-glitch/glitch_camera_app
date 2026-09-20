import 'package:flutter/material.dart';

import '../constants.dart';

class EffectMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EFFECTS',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 18,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 10),
            ...EffectFlags.all.map((e) => _tile(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int flag) {
    final on = (flags & flag) != 0;
    final value = intensities[flag] ?? 0.8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: on,
          onChanged: (_) => onToggle(flag),
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
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.5,
            activeColor: on ? Colors.cyanAccent : Colors.grey,
            inactiveColor: Colors.grey.withOpacity(0.3),
            onChanged: (v) => onIntensityChanged(flag, v),
          ),
        ),
      ],
    );
  }
}

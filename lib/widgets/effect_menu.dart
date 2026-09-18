import 'package:flutter/material.dart';

import '../constants.dart';

class EffectMenu extends StatelessWidget {
  final int flags;
  final ValueChanged<int> onChanged;

  const EffectMenu({
    super.key,
    required this.flags,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
    return CheckboxListTile(
      value: on,
      onChanged: (_) => onChanged(flag),
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
    );
  }
}

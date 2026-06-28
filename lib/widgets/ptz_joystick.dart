import 'package:flutter/material.dart';

import '../services/onvif_service.dart';

/// Bộ điều khiển PTZ dạng D-pad: giữ để xoay liên tục, thả để dừng.
class PtzJoystick extends StatelessWidget {
  const PtzJoystick({super.key, required this.onMove, required this.onStop});

  final void Function(PtzDir dir) onMove;
  final VoidCallback onStop;

  Widget _btn(IconData icon, PtzDir dir) {
    return GestureDetector(
      onTapDown: (_) => onMove(dir),
      onTapUp: (_) => onStop(),
      onTapCancel: onStop,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacer = const SizedBox(width: 52, height: 52);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          spacer,
          _btn(Icons.keyboard_arrow_up, PtzDir.up),
          spacer,
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.keyboard_arrow_left, PtzDir.left),
          spacer,
          _btn(Icons.keyboard_arrow_right, PtzDir.right),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          spacer,
          _btn(Icons.keyboard_arrow_down, PtzDir.down),
          spacer,
        ]),
      ],
    );
  }
}

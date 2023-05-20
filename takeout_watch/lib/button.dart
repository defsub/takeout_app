import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final Widget icon;
  final double? iconSize;
  final VoidCallback? onPressed;

  const CircleButton(
      {required this.icon, this.iconSize, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
        shape: const CircleBorder(),
        color: Colors.black54,
        child: IconButton(
          icon: icon,
          iconSize: iconSize,
          onPressed: onPressed,
        ));
  }
}

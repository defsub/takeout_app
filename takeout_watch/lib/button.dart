import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final Icon icon;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? edgeInsetsGeometry;

  const CircleButton(
      {required this.icon, this.onPressed, this.edgeInsetsGeometry, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        backgroundColor: Colors.black54,
        padding: edgeInsetsGeometry ?? const EdgeInsets.all(20),
      ),
      onPressed: onPressed,
      child: icon,
    );
  }
}

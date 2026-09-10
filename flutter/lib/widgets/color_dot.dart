import 'package:flutter/material.dart';

class ColorDot extends StatelessWidget {
  final String? colorCode;
  final double size;

  const ColorDot({super.key, this.colorCode, this.size = 16});

  @override
  Widget build(BuildContext context) {
    if (colorCode == null) return SizedBox(width: size, height: size);
    final color = _parse(colorCode!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static Color _parse(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

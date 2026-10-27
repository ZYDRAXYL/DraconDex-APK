import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/icon_refs.dart';
import '../core/icon_sets.dart';

/// An icon as both apps store it (EXE core/pickers.js iconRefHtml) — Procress
/// 29 part 7. `svg:<key>` is the desktop catalogue's icon (core/icon_refs.dart),
/// `svg:<set>/<name>` an icon of an open set (core/icon_sets.dart, loaded on
/// first use), `sym:<glyph>` a letter, symbol or emoji, `img:<data URI>` an
/// uploaded picture. Anything else — or nothing — is [fallback].
class DdxRefIcon extends StatelessWidget {
  final String? iconRef;
  final double size;
  final Color? color;
  final IconData fallback;

  const DdxRefIcon(this.iconRef, {super.key, this.size = 20, this.color, this.fallback = Icons.circle_outlined});

  /// Whether [ref] names something this widget draws (not just the fallback).
  static bool draws(String? ref) {
    if (ref == null || ref.isEmpty) return false;
    if (glyphForRef(ref) != null || iconForRef(ref) != null) return true;
    if (ref.startsWith('img:data:image/')) return true;
    return IconSets.isSetRef(ref.startsWith('svg:') ? ref.substring(4) : ref);
  }

  @override
  Widget build(BuildContext context) {
    final r = iconRef;
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    if (r == null || r.isEmpty) return Icon(fallback, size: size, color: c);
    final glyph = glyphForRef(r);
    if (glyph != null) {
      return SizedBox.square(dimension: size,
          child: FittedBox(child: Text(glyph, style: TextStyle(color: c, height: 1))));
    }
    if (r.startsWith('img:data:image/')) {
      final comma = r.indexOf(',');
      try {
        return ClipOval(child: Image.memory(base64Decode(r.substring(comma + 1)), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true));
      } catch (_) {
        return Icon(fallback, size: size, color: c);
      }
    }
    final own = iconForRef(r);
    if (own != null) return Icon(own, size: size, color: c);
    final key = r.startsWith('svg:') ? r.substring(4) : r;
    if (!IconSets.isSetRef(key)) return Icon(fallback, size: size, color: c);
    final parts = key.split('/');
    Widget draw(IconSet? set) {
      final svg = set?.svg(parts[1]);
      if (svg == null) return SizedBox.square(dimension: size);
      return SvgPicture.string(svg, width: size, height: size, theme: SvgTheme(currentColor: c));
    }
    final now = IconSets.loaded(parts[0]);
    if (now != null) return draw(now);
    return FutureBuilder<IconSet?>(future: IconSets.load(parts[0]), builder: (_, s) => draw(s.data));
  }
}

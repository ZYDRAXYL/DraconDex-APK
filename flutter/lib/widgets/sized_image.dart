import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// An image decoded no larger than it is drawn (Procress 19 part 3). An
/// Asset Nest file is the whole photo — a 12-megapixel one is 48 MB once
/// decoded — and without a cache width Flutter decodes all of it for a
/// 150px banner or a 48px tile. Never decodes past the file's own size
/// (cacheWidth does not upscale), and keeps its aspect ratio (only the
/// width is given).
///
/// The width is [width], else the box it is laid out in. [BoxFit.cover]
/// also fills the box's height, so there it leaves room for a picture up to
/// twice as wide as it is tall. Steps of 64px, so a box that animates its
/// width does not decode the picture again on every frame.
class SizedImage extends StatelessWidget {
  final Uint8List bytes;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final bool gaplessPlayback;

  const SizedImage(
    this.bytes, {
    super.key,
    this.fit,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.gaplessPlayback = false,
  });

  int? _cacheWidth(BuildContext context, double? w, double? h) {
    if (w == null || !w.isFinite || w <= 0) return null;
    final across = fit == BoxFit.cover && h != null && h.isFinite ? math.max(w, h * 2) : w;
    final px = across * MediaQuery.devicePixelRatioOf(context);
    return ((px / 64).ceil() * 64).clamp(64, 1 << 14);
  }

  Widget _image(int? cacheWidth) => Image.memory(
        bytes,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        gaplessPlayback: gaplessPlayback,
        cacheWidth: cacheWidth,
      );

  @override
  Widget build(BuildContext context) {
    if (width != null) return _image(_cacheWidth(context, width, height));
    return LayoutBuilder(
      builder: (context, box) => _image(_cacheWidth(
        context,
        box.hasBoundedWidth ? box.maxWidth : null,
        height ?? (box.hasBoundedHeight ? box.maxHeight : null),
      )),
    );
  }
}

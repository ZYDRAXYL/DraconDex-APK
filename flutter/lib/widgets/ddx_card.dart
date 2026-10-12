import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';

/// The registry's three cards (APP docs/COMPONENTS.md; EXE `.card`):
///
///  * [info] — a block of facts, not tappable as a whole;
///  * [link] — the whole card opens something (a module, a Nexus, a page);
///  * [preview] — a picture or a rendered thumbnail of something, clipped to
///    the card's corners, optionally tappable.
enum DdxCardKind { info, link, preview }

/// One card. Surface, hairline and corner come from the theme; nothing is
/// coloured per call site.
class DdxCard extends StatelessWidget {
  const DdxCard({
    super.key,
    required this.child,
    this.kind = DdxCardKind.info,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.padding,
    this.selected = false,
  });

  final Widget child;
  final DdxCardKind kind;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Null keeps the theme's card margin.
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  /// Draws the accent edge a selected link card carries.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final p = ddx.palette;
    Widget body = padding == null ? child : Padding(padding: padding!, child: child);
    if (onTap != null || onLongPress != null) {
      body = InkWell(onTap: onTap, onLongPress: onLongPress, child: body);
    }
    return Card(
      margin: margin,
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: kind == DdxCardKind.info && onTap == null ? Clip.none : Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ddx.radiusLarge),
        side: BorderSide(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
      ),
      child: body,
    );
  }
}

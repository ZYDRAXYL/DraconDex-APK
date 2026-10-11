import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';

/// Which edges of a glass pane carry the hairline: all round for a floating
/// pane, the one edge that meets the page for a docked bar.
enum DdxGlassEdge { all, top, bottom, end, none }

/// A pane of the Glass UI style (APP Plan.md Procress 23): the backdrop
/// blurred, the theme's surface over it at the theme's glass tint, and a
/// hairline round it — ClipRRect + BackdropFilter + tint + stroke, all from
/// the `platform.glass` tokens on [DdxThemeExt].
///
/// Only for chrome and floating layers — app bars, the Navibar and the rail,
/// bottom sheets, dialogs. Never page content, list rows, tables or editors:
/// long reading needs an opaque ground, and a blur per row is the expensive
/// way to draw a list. Callers decide where Glass applies
/// (`context.isGlassStyle`); this always draws a pane, in one of three ways:
///
///  * **glass** — blur + tint + stroke;
///  * **tint only** — this device drew the blur too slowly
///    (`DdxThemeExt.glassBlurOff`, core/theme/glass_probe.dart);
///  * **opaque** — "Reduce transparency" or the OS's high contrast
///    (`context.glassOpaque`): the same surface, solid, and no BackdropFilter
///    anywhere in the pane.
///
/// Named like the `DdxGlass` token class in tokens.g.dart on purpose — the
/// component and its tokens. A file that needs both imports tokens.g.dart
/// with a prefix (or `hide DdxGlass`); this widget reads the tokens through
/// `context.ddx` and never needs to.
class DdxGlass extends StatelessWidget {
  const DdxGlass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.edge = DdxGlassEdge.all,
    this.backdrop = false,
    this.shadow = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final DdxGlassEdge edge;

  /// Paint the theme's backdrop gradient (glass-backdrop-from → -to) under
  /// the pane. A docked bar sits over the page's opaque ground, which leaves
  /// the blur nothing to show; the gradient is aligned to the screen, not to
  /// the bar, so every bar is a window onto the same one backdrop.
  final bool backdrop;

  /// A floating pane's lift (glass-shadow). Drawn outside the pane only:
  /// under a translucent pane it would darken the tint the contrast check
  /// counted on.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final opaque = context.glassOpaque;
    // width 0 = a hairline: one device pixel at any density.
    final side = BorderSide(color: ddx.glassStroke, width: 0);
    final BoxBorder? border = switch (edge) {
      DdxGlassEdge.all => Border.fromBorderSide(side),
      DdxGlassEdge.top => Border(top: side),
      DdxGlassEdge.bottom => Border(bottom: side),
      DdxGlassEdge.end => BorderDirectional(end: side),
      DdxGlassEdge.none => null,
    };
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        color: opaque ? ddx.palette.surface : ddx.glassSurface,
        border: border,
        // a radius takes a uniform border only; a one-edge bar has none
        borderRadius: edge == DdxGlassEdge.all ? borderRadius : null,
      ),
      child: child,
    );
    if (!opaque) {
      if (!ddx.glassBlurOff) {
        pane = BackdropFilter(filter: ImageFilter.blur(sigmaX: ddx.glassBlur, sigmaY: ddx.glassBlur), child: pane);
      }
      if (backdrop) {
        pane = Stack(children: [
          Positioned.fill(child: DdxGlassBackdrop(from: ddx.glassBackdropFrom, to: ddx.glassBackdropTo)),
          pane,
        ]);
      }
    }
    // The clip is what bounds the blur: a BackdropFilter with no clip above
    // it filters the whole screen.
    pane = borderRadius == BorderRadius.zero
        ? ClipRect(child: pane)
        : ClipRRect(borderRadius: borderRadius, child: pane);
    if (shadow) {
      pane = CustomPaint(painter: _OuterShadow(ddx.glassShadow, borderRadius), child: pane);
    }
    return pane;
  }
}

/// The gradient behind the glass, aligned to the screen rather than to the
/// box it fills: a bar at the top and the Navibar at the bottom show the two
/// ends of one backdrop, not two copies of it.
class DdxGlassBackdrop extends LeafRenderObjectWidget {
  const DdxGlassBackdrop({super.key, required this.from, required this.to});

  final Color from;
  final Color to;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(from, to, MediaQuery.sizeOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderGlassBackdrop)
      ..from = from
      ..to = to
      ..screen = MediaQuery.sizeOf(context);
  }
}

class _RenderGlassBackdrop extends RenderBox {
  _RenderGlassBackdrop(this._from, this._to, this._screen);

  Color _from, _to;
  Size _screen;

  set from(Color v) {
    if (v == _from) return;
    _from = v;
    markNeedsPaint();
  }

  set to(Color v) {
    if (v == _to) return;
    _to = v;
    markNeedsPaint();
  }

  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Where this box is on screen, so the gradient can be laid over the
    // whole screen and this box shows its own part of it.
    final origin = localToGlobal(Offset.zero);
    final screenRect = (offset - origin) & _screen;
    final shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_from, _to])
        .createShader(screenRect);
    context.canvas.drawRect(offset & size, Paint()..shader = shader);
  }
}

class _OuterShadow extends CustomPainter {
  const _OuterShadow(this.shadows, this.radius);

  final List<BoxShadow> shadows;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final pane = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(200))
      ..addRRect(pane));
    for (final s in shadows) {
      canvas.drawRRect(pane.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) => old.shadows != shadows || old.radius != radius;
}

/// An app bar as a glass bar when Glass is on, otherwise the bar as given.
/// Wraps any [PreferredSizeWidget] for `Scaffold.appBar`; the bar's own
/// background goes transparent so the pane under it shows.
class DdxGlassBar extends StatelessWidget implements PreferredSizeWidget {
  const DdxGlassBar({super.key, required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!context.isGlassStyle) return child;
    return DdxGlass(
      edge: DdxGlassEdge.bottom,
      backdrop: true,
      child: AppBarTheme(
        data: AppBarTheme.of(context).copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}

/// Material 3's sheet corner.
const _sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

/// The scrim behind a glass sheet or dialog: the theme's own background, not
/// black. A dark scrim under a light theme's pane drags it toward grey and
/// out of the contrast SDB checked; washing the page toward bg keeps what
/// the blur sees inside the backdrop the tint was computed for.
Color _glassScrim(BuildContext context) => context.ddx.palette.bg.withValues(alpha: 0.5);

/// The barrier for a modal that draws its own glass pane: the glass scrim
/// on the Glass style, otherwise null (the route's default).
Color? glassBarrierColor(BuildContext context) =>
    context.isGlassStyle && !context.glassOpaque ? _glassScrim(context) : null;

/// [showModalBottomSheet] for the app: the same sheet when Glass is off, and
/// a glass pane when it is on. Every sheet in the app opens through this, so
/// the UI style reaches all of them.
Future<T?> showDdxSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool? showDragHandle,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
}) {
  if (!context.isGlassStyle) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      showDragHandle: showDragHandle,
      constraints: constraints,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
    );
  }
  // The sheet's own Material goes clear and the pane draws everything,
  // drag handle included — Material's handle sits outside the builder, and
  // would be left floating on nothing above the pane.
  final handle = showDragHandle ?? false;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    showDragHandle: false,
    constraints: constraints,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.none,
    barrierColor: glassBarrierColor(context),
    builder: (ctx) => DdxGlass(
      borderRadius: _sheetRadius,
      shadow: true,
      // Ink lands on the nearest Material — without this one, under the pane.
      child: Material(
        type: MaterialType.transparency,
        child: !handle
            ? builder(ctx)
            : Stack(alignment: Alignment.topCenter, children: [
                const _SheetHandle(),
                Padding(padding: const EdgeInsets.only(top: kMinInteractiveDimension), child: builder(ctx)),
              ]),
      ),
    ),
  );
}

/// Material 3's drag handle, drawn inside the pane.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      container: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: SizedBox(
        height: kMinInteractiveDimension,
        width: kMinInteractiveDimension,
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// [showDialog] for the app: the same dialog when Glass is off; when it is
/// on, the dialog's own panel takes the glass tint and hairline and the page
/// behind it is blurred.
///
/// The blur covers the page rather than being clipped to the panel: a
/// dialog's panel is drawn inside AlertDialog/SimpleDialog, where nothing
/// can sit under it, and the page behind a modal is out of use anyway — one
/// layer either way, and every dialog in the app gets it without being
/// rewritten.
Future<T?> showDdxDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  if (!context.isGlassStyle) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: glassBarrierColor(context),
    builder: (ctx) => _GlassDialogScope(child: builder(ctx)),
  );
}

class _GlassDialogScope extends StatelessWidget {
  const _GlassDialogScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final opaque = context.glassOpaque;
    final dialog = DialogTheme(
      data: DialogTheme.of(context).copyWith(
        backgroundColor: opaque ? ddx.palette.surface : ddx.glassSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ddx.radiusLarge),
          side: BorderSide(color: ddx.glassStroke, width: 0),
        ),
      ),
      child: child,
    );
    if (opaque || ddx.glassBlurOff) return dialog;
    return BackdropFilter(filter: ImageFilter.blur(sigmaX: ddx.glassBlur, sigmaY: ddx.glassBlur), child: dialog);
  }
}

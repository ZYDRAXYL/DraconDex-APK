import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoModalPopupRoute;
import 'package:flutter/material.dart';

import '../core/layout/breakpoints.dart';
import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart' hide DdxGlass;
import 'ddx_glass.dart';

/// How a popover was shown — what [showDdxPopover] chose for this screen.
enum DdxPopoverMode { anchored, sheet, dialog }

/// Which one [showDdxPopover] would use from [context]: anchored beside its
/// anchor on a tablet or a desktop-width window, a bottom sheet on a phone —
/// and, on a phone already inside a sheet, a dialog: a sheet over a sheet
/// is a level the depth rule does not allow (test/ui_depth_test.dart).
DdxPopoverMode ddxPopoverModeOf(BuildContext context) {
  if (!ddxLayoutOf(context).isPhone) return DdxPopoverMode.anchored;
  final route = ModalRoute.of(context);
  if (route is ModalBottomSheetRoute || route is CupertinoModalPopupRoute) return DdxPopoverMode.dialog;
  return DdxPopoverMode.sheet;
}

/// The small "pick a value / set one thing" layer — the registry's popover
/// (APP docs/COMPONENTS.md; EXE `openPopover`). A full form is still a
/// dialog ([showDdxDialog]).
///
/// The anchor is [anchorRect] (global coordinates), else [anchorKey]'s box,
/// else the box of [context] itself — so a button that passes its own
/// context needs nothing else. Esc and a tap outside close it; focus stays
/// inside while it is open (it is a modal route). Glass applies the way it
/// does to every floating layer.
///
/// [builder] returns the content only — a column of options, a small form.
/// Close with `Navigator.pop(context, value)` from inside it, in every mode.
Future<T?> showDdxPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlobalKey? anchorKey,
  Rect? anchorRect,
  double width = 280,
  double maxHeight = 440,
  String? semanticLabel,
}) {
  switch (ddxPopoverModeOf(context)) {
    case DdxPopoverMode.sheet:
      return showDdxSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: builder(ctx),
          ),
        ),
      );
    case DdxPopoverMode.dialog:
      return showDdxDialog<T>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
            child: builder(ctx),
          ),
        ),
      );
    case DdxPopoverMode.anchored:
      final navigator = Navigator.of(context);
      final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
      Rect anchor;
      if (anchorRect != null) {
        anchor = anchorRect.shift(-overlay.localToGlobal(Offset.zero));
      } else {
        final box = (anchorKey?.currentContext ?? context).findRenderObject() as RenderBox?;
        anchor = box == null || !box.hasSize
            ? Rect.fromCenter(center: overlay.size.center(Offset.zero), width: 0, height: 0)
            : box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
      }
      return navigator.push<T>(_DdxPopoverRoute<T>(
        anchor: anchor,
        builder: builder,
        width: width,
        maxHeight: maxHeight,
        semanticLabel: semanticLabel,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      ));
  }
}

/// A widget that opens a popover anchored to itself — [showDdxPopover]
/// for a trigger built inline. [anchorBuilder] gets an `open` callback to
/// wire to its button; whatever the content pops with arrives in [onClosed].
class DdxPopover<T> extends StatelessWidget {
  const DdxPopover({
    super.key,
    required this.anchorBuilder,
    required this.builder,
    this.onClosed,
    this.width = 280,
    this.maxHeight = 440,
    this.semanticLabel,
  });

  final Widget Function(BuildContext context, VoidCallback open) anchorBuilder;
  final WidgetBuilder builder;
  final ValueChanged<T?>? onClosed;
  final double width;
  final double maxHeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) => anchorBuilder(anchorContext, () async {
        final v = await showDdxPopover<T>(
          context: anchorContext,
          builder: builder,
          width: width,
          maxHeight: maxHeight,
          semanticLabel: semanticLabel,
        );
        onClosed?.call(v);
      }),
    );
  }
}

class _DdxPopoverRoute<T> extends PopupRoute<T> {
  _DdxPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.width,
    required this.maxHeight,
    required this.barrierLabel,
    required this.capturedThemes,
    this.semanticLabel,
  });

  final Rect anchor;
  final WidgetBuilder builder;
  final double width;
  final double maxHeight;
  final String? semanticLabel;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => DdxMotion.durFast;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: DdxMotion.easeStandard), child: child);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final padding = MediaQuery.paddingOf(context);
    return capturedThemes.wrap(
      CustomSingleChildLayout(
        delegate: DdxPopoverLayout(anchor: anchor, width: width, maxHeight: maxHeight, safe: padding),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: semanticLabel,
          child: _DdxPopoverPane(child: Builder(builder: builder)),
        ),
      ),
    );
  }
}

/// The popover's one positioner: below the anchor, start-aligned with it;
/// flipped above when below has less room; shifted to stay [margin] inside
/// the screen. EXE's `openPopover` places the same way.
class DdxPopoverLayout extends SingleChildLayoutDelegate {
  const DdxPopoverLayout({
    required this.anchor,
    required this.width,
    required this.maxHeight,
    this.safe = EdgeInsets.zero,
    this.gap = 4,
    this.margin = 8,
  });

  final Rect anchor;
  final double width;
  final double maxHeight;
  final EdgeInsets safe;
  final double gap;
  final double margin;

  double _below(Size size) => size.height - safe.bottom - margin - (anchor.bottom + gap);
  double _above(Size size) => anchor.top - gap - (safe.top + margin);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final room = math.max(_below(size), _above(size));
    return BoxConstraints(
      maxWidth: math.max(0, math.min(width, size.width - 2 * margin)),
      maxHeight: math.max(0, math.min(maxHeight, room)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size);
    final y = fitsBelow || _below(size) >= _above(size) ? anchor.bottom + gap : anchor.top - gap - childSize.height;
    final x = anchor.left.clamp(margin, math.max(margin, size.width - margin - childSize.width)).toDouble();
    return Offset(x, y.clamp(safe.top + margin, math.max(safe.top + margin, size.height - margin - childSize.height)).toDouble());
  }

  @override
  bool shouldRelayout(DdxPopoverLayout old) =>
      old.anchor != anchor || old.width != width || old.maxHeight != maxHeight || old.safe != safe;
}

class _DdxPopoverPane extends StatelessWidget {
  const _DdxPopoverPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final radius = BorderRadius.circular(ddx.radiusLarge);
    final content = Material(type: MaterialType.transparency, child: child);
    if (context.isGlassStyle) {
      return DdxGlass(borderRadius: radius, shadow: true, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ddx.palette.raised,
        borderRadius: radius,
        border: Border.all(color: ddx.palette.border),
        boxShadow: DdxShadow.shadowMenu,
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}

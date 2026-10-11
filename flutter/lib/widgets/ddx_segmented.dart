import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart' hide DdxGlass;

/// One choice in a [DdxSegmented].
@immutable
class DdxSegment<T> {
  const DdxSegment({required this.value, required this.label, this.icon, this.tooltip});

  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;
}

/// One-of-a-few choice on one row — the registry's `segmented` (APP
/// docs/COMPONENTS.md; EXE `.seg`). Material 3's [SegmentedButton] on
/// Android and the web, a sliding segmented control on iPhone/iPad.
///
/// Colours are the contrast contract SDB checked in all 32 themes: the
/// unselected label t1 on raised, the selected segment on-accent on accent.
class DdxSegmented<T extends Object> extends StatelessWidget {
  const DdxSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.multiline = false,
  });

  final List<DdxSegment<T>> segments;
  final T selected;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Labels may wrap to two lines; the segment grows instead of clipping
  /// to Material's 40dp.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final p = ddx.palette;
    if (context.isIosStyle) {
      final control = CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        backgroundColor: p.raised,
        thumbColor: p.accent,
        onValueChanged: (v) {
          if (v != null) onChanged?.call(v);
        },
        children: {
          for (final s in segments)
            s.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DdxSpace.sp3, vertical: DdxSpace.sp2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s.icon != null) ...[
                  Icon(s.icon, size: DdxSize.iconSm, color: s.value == selected ? ddx.onAccent : p.t1),
                  const SizedBox(width: DdxSpace.sp1),
                ],
                Flexible(
                  child: Text(
                    s.label,
                    maxLines: multiline ? 2 : 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: s.value == selected ? ddx.onAccent : p.t1),
                  ),
                ),
              ]),
            ),
        },
      );
      if (onChanged != null) return control;
      return IgnorePointer(child: Opacity(opacity: 0.5, child: control));
    }
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ddx.onAccent : p.t1,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.raised,
        ),
        minimumSize: multiline ? const WidgetStatePropertyAll(Size(0, 48)) : null,
        maximumSize: multiline ? const WidgetStatePropertyAll(Size(double.infinity, 72)) : null,
        padding: multiline
            ? const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6))
            : null,
      ),
      segments: [
        for (final s in segments)
          ButtonSegment<T>(
            value: s.value,
            tooltip: s.tooltip,
            icon: s.icon == null ? null : Icon(s.icon),
            label: Text(s.label, maxLines: multiline ? 2 : 1, textAlign: TextAlign.center),
          ),
      ],
      selected: {selected},
      onSelectionChanged: onChanged == null ? null : (v) => onChanged!(v.first),
    );
  }
}

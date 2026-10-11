import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart' hide DdxGlass;

/// The four chips of the component registry (APP docs/COMPONENTS.md, EXE
/// `.chip`): a `#` tag, a filter that toggles, a status label, and a label
/// with a count. Every hand-rolled pill in the app is one of these.
enum DdxChipKind { tag, filter, status, count }

/// The two chip heights — `--ctl-sm` and `--ctl-md`.
enum DdxChipSize { sm, md }

/// What a status chip says about its subject. Only [warn] and [info] fill
/// the chip (with their own on-colours); the rest keep the label in t1 and
/// carry the tone as a dot — danger, success and accent as text fail 4.5:1
/// on a surface in a dozen or more themes (SDB contrast survey).
enum DdxTone { neutral, accent, success, warn, info, danger }

/// One chip. Colours follow the contrast contract SDB checked across all 32
/// themes: the label is t1 on `hover`, a selected filter is on-accent on
/// accent, and a status is either a t1 label with a tone dot or a warn/info
/// fill. A tag's own colour is user data: it is the dot, never the label.
class DdxChip extends StatelessWidget {
  const DdxChip({
    super.key,
    required this.label,
    this.kind = DdxChipKind.tag,
    this.size = DdxChipSize.md,
    this.selected = false,
    this.onTap,
    this.onSelected,
    this.onDeleted,
    this.color,
    this.tone = DdxTone.neutral,
    this.count,
    this.icon,
    this.tooltip,
  });

  /// A `#name` tag. [color] is the tag's own colour (user data), drawn as a
  /// dot; the `#` is added here.
  const DdxChip.tag(
    String name, {
    Key? key,
    Color? color,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    DdxChipSize size = DdxChipSize.md,
  }) : this(key: key, label: name, kind: DdxChipKind.tag, color: color, onTap: onTap, onDeleted: onDeleted, size: size);

  /// A toggle: one of several values (a ChoiceChip's job) or an on/off
  /// filter (a FilterChip's).
  const DdxChip.filter(
    String label, {
    Key? key,
    required bool selected,
    required ValueChanged<bool>? onSelected,
    IconData? icon,
    VoidCallback? onDeleted,
    DdxChipSize size = DdxChipSize.md,
  }) : this(
          key: key,
          label: label,
          kind: DdxChipKind.filter,
          selected: selected,
          onSelected: onSelected,
          icon: icon,
          onDeleted: onDeleted,
          size: size,
        );

  /// A status label.
  const DdxChip.status(
    String label, {
    Key? key,
    DdxTone tone = DdxTone.neutral,
    IconData? icon,
    VoidCallback? onTap,
    DdxChipSize size = DdxChipSize.md,
  }) : this(key: key, label: label, kind: DdxChipKind.status, tone: tone, icon: icon, onTap: onTap, size: size);

  /// A label and how many there are.
  const DdxChip.count(
    String label,
    int count, {
    Key? key,
    VoidCallback? onTap,
    DdxChipSize size = DdxChipSize.md,
  }) : this(key: key, label: label, kind: DdxChipKind.count, count: count, onTap: onTap, size: size);

  final String label;
  final DdxChipKind kind;
  final DdxChipSize size;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;

  /// A tag's own colour (user data). Ignored by the other kinds.
  final Color? color;
  final DdxTone tone;
  final int? count;
  final IconData? icon;
  final String? tooltip;

  bool get _interactive => onTap != null || onSelected != null;

  /// The label as it reads, `#` included.
  String get text => kind == DdxChipKind.tag ? '#$label' : label;

  /// The chip's fill and its label colour — the pairs the contrast test
  /// checks in every theme.
  static (Color fill, Color ink) colorsFor(
    DdxThemeExt ddx, {
    required DdxChipKind kind,
    bool selected = false,
    DdxTone tone = DdxTone.neutral,
  }) {
    final p = ddx.palette;
    if (kind == DdxChipKind.filter && selected) return (p.accent, ddx.onAccent);
    if (kind == DdxChipKind.status && tone == DdxTone.warn) return (ddx.warn, ddx.onWarn);
    if (kind == DdxChipKind.status && tone == DdxTone.info) return (ddx.info, ddx.onInfo);
    return (p.hover, p.t1);
  }

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final p = ddx.palette;
    final (fill, ink) = colorsFor(ddx, kind: kind, selected: selected, tone: tone);
    final height = size == DdxChipSize.sm ? DdxSize.ctlSm : DdxSize.ctlMd;
    final fontSize = size == DdxChipSize.sm ? DdxFontSize.fsSm : DdxFontSize.fsBody;
    final iconSize = size == DdxChipSize.sm ? DdxSize.iconSm - 2 : DdxSize.iconSm;

    final Color? dot = switch (kind) {
      DdxChipKind.tag => color,
      DdxChipKind.status => switch (tone) {
          DdxTone.accent => p.accent,
          DdxTone.success => p.success,
          DdxTone.danger => p.danger,
          _ => null,
        },
      _ => null,
    };

    final children = <Widget>[
      if (dot != null) ...[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: DdxSpace.sp2),
      ],
      if (kind == DdxChipKind.filter && selected && icon == null) ...[
        Icon(Icons.check, size: iconSize, color: ink),
        const SizedBox(width: DdxSpace.sp1),
      ] else if (icon != null) ...[
        Icon(icon, size: iconSize, color: ink),
        const SizedBox(width: DdxSpace.sp1),
      ],
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ink, fontSize: fontSize, fontWeight: FontWeight.w500, height: 1.2),
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: DdxSpace.sp2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: DdxSpace.sp2),
          decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(height / 2)),
          child: Text('$count', style: TextStyle(color: p.t1, fontSize: fontSize - 1, fontWeight: FontWeight.w700)),
        ),
      ],
      if (onDeleted != null) ...[
        const SizedBox(width: DdxSpace.sp1),
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).deleteButtonTooltip,
          child: InkResponse(
            onTap: onDeleted,
            radius: height / 2,
            child: Icon(Icons.close, size: iconSize, color: ink),
          ),
        ),
      ],
    ];

    final shape = StadiumBorder(
      side: kind == DdxChipKind.filter && !selected ? BorderSide(color: p.border) : BorderSide.none,
    );
    Widget chip = Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !_interactive ? null : () => onSelected != null ? onSelected!(!selected) : onTap!(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size == DdxChipSize.sm ? DdxSpace.sp3 : DdxSpace.sp5),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
    if (_interactive || onDeleted != null) {
      // The visible pill stays at --ctl-*; the target round it reaches the
      // 48dp Material asks for, the way Material's own chips pad theirs.
      final padded = Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
      if (padded) {
        chip = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
          child: Center(widthFactor: 1, child: chip),
        );
      }
    }
    chip = Semantics(
      container: true,
      button: _interactive,
      selected: kind == DdxChipKind.filter ? selected : null,
      child: chip,
    );
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
  }
}

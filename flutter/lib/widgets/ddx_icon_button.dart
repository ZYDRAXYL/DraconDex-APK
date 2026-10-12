import 'package:flutter/material.dart';

import '../core/theme/tokens.g.dart' hide DdxGlass;

/// Icon sizes — `--icon-sm`, `--icon-md`, and Material's 24.
enum DdxIconSize { sm, md, lg }

/// The one icon button (APP docs/COMPONENTS.md; EXE `.btn-i`). The target is
/// at least 48dp whatever the icon's size, and [tooltip] is required: it is
/// the button's accessible name, and an icon alone names nothing to a
/// screen reader.
class DdxIconButton extends StatelessWidget {
  const DdxIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = DdxIconSize.lg,
    this.color,
    this.selected,
    this.selectedIcon,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final DdxIconSize size;
  final Color? color;

  /// Non-null makes it a toggle: announced as selected, [selectedIcon] shown.
  final bool? selected;
  final IconData? selectedIcon;

  static double sizeOf(DdxIconSize s) => switch (s) {
        DdxIconSize.sm => DdxSize.iconSm,
        DdxIconSize.md => DdxSize.iconMd,
        DdxIconSize.lg => 24,
      };

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      selectedIcon: selectedIcon == null ? null : Icon(selectedIcon),
      isSelected: selected,
      tooltip: tooltip,
      onPressed: onPressed,
      color: color,
      iconSize: sizeOf(size),
      constraints: const BoxConstraints(minWidth: kMinInteractiveDimension, minHeight: kMinInteractiveDimension),
    );
  }
}

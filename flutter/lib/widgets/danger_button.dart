import 'package:flutter/material.dart';

/// The component contract's fourth button (APP docs/redesign/COMPONENTS.md):
/// a destructive action, filled in the theme's error colour — the desktop's
/// .btn-d. Primary, secondary and ghost come from the theme
/// (Filled/Outlined/TextButton); this one is a widget because Material has
/// no "danger" variant to theme.
class DdxDangerButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const DdxDangerButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
      child: child,
    );
  }
}

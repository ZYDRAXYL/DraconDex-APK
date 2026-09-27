import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/ddx_theme.dart';

/// One entry of a row's menu.
class RowAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Drawn in the error colour — delete, and whatever else cannot be undone.
  final bool danger;

  const RowAction({required this.label, required this.icon, required this.onTap, this.danger = false});
}

/// A row's menu as a bottom sheet — what a long press opens (APK V3, APP
/// docs/APK-V3.md §5): the phone's answer to the desktop's right-click.
///
/// The sheet closes before the action runs, so an action that opens a dialog
/// of its own does not open it over a sheet on its way out.
///
/// On iPhone/iPad it is an action sheet instead — the Apple-app layer (APP
/// docs/REDESIGN.md C3): destructive actions in red, Cancel apart at the
/// bottom. Same actions, same close-then-run order.
Future<void> showRowMenu(BuildContext context, List<RowAction> actions, {String? title}) async {
  if (actions.isEmpty) return;
  if (context.isIosStyle) {
    // Cupertino draws in SF, which an iPhone has but the web build (the PWA
    // on Safari) does not bundle — there it would fall back to a font
    // fetched from the network, i.e. nothing offline. Use the app's own.
    const web = kIsWeb ? TextStyle(fontFamily: 'NotoSans') : null;
    final picked = await showCupertinoModalPopup<RowAction>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: web),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.danger,
              onPressed: () => Navigator.of(sheetContext).pop(a),
              child: Text(a.label, style: web),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(AppLocalizations.of(context)!.btnCancel, style: web),
        ),
      ),
    );
    picked?.onTap();
    return;
  }
  final picked = await showModalBottomSheet<RowAction>(
    context: context,
    // Over the Navibar, not under it: the shell's own navigator sits
    // above the bar, so a sheet opened on it would be cut off by it.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            for (final a in actions) _RowActionTile(action: a, onTap: () => Navigator.of(sheetContext).pop(a)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  picked?.onTap();
}

class _RowActionTile extends StatelessWidget {
  final RowAction action;
  final VoidCallback onTap;

  const _RowActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = action.danger ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(action.icon, color: color),
      title: Text(action.label, style: color == null ? null : TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

/// The ⋮ every row carries — the second way into the same menu the long press
/// opens, because a long press is invisible (APP docs/APK-V3.md §5). It opens
/// the same sheet rather than a popup, so both ways look alike.
class RowMenuButton extends StatelessWidget {
  final List<RowAction> Function() actions;
  final String? title;
  final double iconSize;

  /// A bare icon without the 40dp tap target — for the hub tree, whose rows
  /// are shorter than one.
  final bool dense;

  const RowMenuButton({super.key, required this.actions, this.title, this.iconSize = 20, this.dense = false});

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return Tooltip(
        message: AppLocalizations.of(context)!.rowMore,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => showRowMenu(context, actions(), title: title),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.more_vert, size: iconSize),
          ),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.more_vert),
      iconSize: iconSize,
      visualDensity: VisualDensity.compact,
      tooltip: AppLocalizations.of(context)!.rowMore,
      onPressed: () => showRowMenu(context, actions(), title: title),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/row_menu.dart';
import 'dialogs/module_dialog.dart';

/// A module's menu — one list for every place a module is a row (a tile, a
/// card, a hub-tree row) and for its own page's ⋮, so the two ways in
/// (long press, ⋮) and the page itself never disagree (APP docs/APK-V3.md §5).
///
/// [onOwnPage] leaves "open" out and, after a delete, walks up to the parent
/// rather than staying on a page that no longer exists.
List<RowAction> moduleRowActions(
  BuildContext context,
  WidgetRef ref,
  ModuleModel module, {
  bool onOwnPage = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final nexusId = module.nexusRef;
  return [
    if (!onOwnPage)
      RowAction(
        label: l10n.rowOpen,
        icon: Icons.open_in_new,
        onTap: () => context.push(RecentView.locationFor(nexusId, module.id)),
      ),
    RowAction(
      label: module.pinned ? l10n.btnUnpin : l10n.btnPin,
      icon: module.pinned ? Icons.push_pin : Icons.push_pin_outlined,
      onTap: () async {
        final dao = ref.read(moduleDaoProvider).valueOrNull;
        await dao?.setPinned(module.id, !module.pinned);
        _refreshModule(ref, module);
      },
    ),
    RowAction(
      label: l10n.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        await showDialog(context: context, builder: (_) => ModuleDialog(nexusId: nexusId, existing: module));
        _refreshModule(ref, module);
      },
    ),
    RowAction(
      label: l10n.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () => _deleteModule(context, ref, module, onOwnPage: onOwnPage),
    ),
  ];
}

void _refreshModule(WidgetRef ref, ModuleModel module) {
  ref.invalidate(moduleProvider(module.id));
  ref.invalidate(moduleChildrenProvider(ModuleChildrenKey(module.nexusRef, module.parentId)));
  ref.invalidate(pinnedModulesProvider(module.nexusRef));
  ref.invalidate(nexusIndexProvider(module.nexusRef));
}

Future<void> _deleteModule(BuildContext context, WidgetRef ref, ModuleModel module, {required bool onOwnPage}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showConfirmDialog(
    context,
    title: '${l10n.confirmDeleteTitle}: "${module.name}"',
    message: l10n.deleteModuleMessage,
  );
  if (!ok) return;
  final dao = ref.read(moduleDaoProvider).valueOrNull;
  await dao?.deleteModule(module.id);
  _refreshModule(ref, module);
  await ref.read(recentViewsProvider.notifier).removeForModule(module.nexusRef, module.id);
  if (onOwnPage && context.mounted) {
    context.go(RecentView.locationFor(module.nexusRef, module.parentId));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/services/trash_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/row_menu.dart';
import '../export/export_sheet.dart';
import '../tools/trash_screen.dart';
import 'dialogs/module_dialog.dart';

/// A module's menu — one list for every place a module is a row (a tile, a
/// card, a hub-tree row) and for its own page's ⋮, so the two ways in
/// (long press, ⋮) and the page itself never disagree (APP docs/APK-V3.md §5).
///
/// [onOwnPage] leaves "open" out and, after a delete, walks up to the parent
/// rather than staying on a page that no longer exists. On an element's page
/// [itemKey]/[itemName] make Export… that element's.
List<RowAction> moduleRowActions(
  BuildContext context,
  WidgetRef ref,
  ModuleModel module, {
  bool onOwnPage = false,
  String? itemKey,
  String? itemName,
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
    // Every way out — PDF, Word, EPUB, tables, web page, Markdown, .mddx
    // (APP docs/EXPORT-DECOR.md E8).
    RowAction(
      label: l10n.exportTitle,
      icon: Icons.ios_share,
      onTap: () => showExportSheet(context, ref, module, itemKey: itemKey, itemName: itemName),
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

/// A delete goes to the Trash (V5.md §11.4): no confirm, an Undo instead.
Future<void> _deleteModule(BuildContext context, WidgetRef ref, ModuleModel module, {required bool onOwnPage}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final db = await ref.read(databaseProvider.future);
  final trashId = await TrashService.trashModule(db, module.nexusRef, module.id);
  if (trashId == null) return;
  _refreshModule(ref, module);
  refreshAfterTrash(ref, module.nexusRef);
  await ref.read(recentViewsProvider.notifier).removeForModule(module.nexusRef, module.id);
  if (onOwnPage) router.go(RecentView.locationFor(module.nexusRef, module.parentId));
  messenger.showSnackBar(SnackBar(
    content: Text('${l10n.trashMoved}: ${module.name}'),
    action: SnackBarAction(
      label: l10n.btnUndo,
      onPressed: () async {
        final id = await restoreFromTrash(ref, module.nexusRef, trashId);
        if (id != null && onOwnPage) router.go(RecentView.locationFor(module.nexusRef, id));
      },
    ),
  ));
}

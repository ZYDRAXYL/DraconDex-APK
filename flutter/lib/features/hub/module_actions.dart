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
import 'dialogs/artisan_sheet.dart';
import 'dialogs/module_dialog.dart';
import 'widgets/move_to_sheet.dart';

/// A module's menu — one list for every place a module is a row (a tile, a
/// card, a hub-tree row) and for its own page's ⋮, so the two ways in
/// (long press, ⋮) and the page itself never disagree (APP docs/APK-V3.md §5).
///
/// [inTree]: a hub-tree row, whose level has no page open to select on.
/// [onOwnPage] leaves "open" out and, after a delete, walks up to the parent
/// rather than staying on a page that no longer exists. On an element's page
/// [itemKey]/[itemName] make Export… that element's.
List<RowAction> moduleRowActions(
  BuildContext context,
  WidgetRef ref,
  ModuleModel module, {
  bool onOwnPage = false,
  bool inTree = false,
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
    // Sorting into folders (APP docs/ASSET-PACK.md §1): the moves a file
    // manager has, which is what lets a phone lay out the folders the
    // desktop rebuilds on disk from a .dxpack.
    RowAction(
      label: l10n.moveTo,
      icon: Icons.drive_file_move_outline,
      onTap: () => moveModulesWithPicker(context, ref, [module]),
    ),
    if (!onOwnPage) ...[
      RowAction(
        label: l10n.pbLinkUp,
        icon: Icons.arrow_upward,
        onTap: () => _shift(ref, module, -1),
      ),
      RowAction(
        label: l10n.pbLinkDown,
        icon: Icons.arrow_downward,
        onTap: () => _shift(ref, module, 1),
      ),
      if (!inTree)
      RowAction(
        label: l10n.selectItems,
        icon: Icons.check_circle_outline,
        onTap: () => ref
            .read(moduleSelectionProvider(ModuleChildrenKey(nexusId, module.parentId)).notifier)
            .state = {module.id},
      ),
    ],
    // A folder, as one of the user's own Artisan bundles (TEMPLATES.md §4.4).
    if (module.kind == ModuleKind.collector)
      RowAction(
        label: l10n.bundleSaveMine,
        icon: Icons.inventory_2_outlined,
        onTap: () => showSaveBundleDialog(context, ref, module),
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

Future<void> _shift(WidgetRef ref, ModuleModel module, int delta) async {
  final dao = ref.read(moduleDaoProvider).valueOrNull;
  await dao?.shiftModule(module.id, delta);
  ref.invalidate(moduleChildrenProvider(ModuleChildrenKey(module.nexusRef, module.parentId)));
}

/// Asks where, then moves [modules] (all of one Nexus) there.
Future<void> moveModulesWithPicker(BuildContext context, WidgetRef ref, List<ModuleModel> modules) async {
  if (modules.isEmpty) return;
  final target = await showMoveToSheet(
    context,
    nexusId: modules.first.nexusRef,
    moving: {for (final m in modules) m.id},
    startAt: modules.first.parentId,
  );
  if (target == null || !context.mounted) return;
  await moveModulesInto(context, ref, modules, target.parentId, target.name);
}

/// Moves [modules] under the Collector [parentId] (null = top level) and
/// says so. A module the target sits inside is left where it is — a folder
/// cannot go into itself — and the one-line answer says that instead.
Future<void> moveModulesInto(
    BuildContext context, WidgetRef ref, List<ModuleModel> modules, int? parentId, String targetName) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(moduleDaoProvider).valueOrNull;
  if (dao == null || modules.isEmpty) return;
  final nexusId = modules.first.nexusRef;
  final todo = [for (final m in modules) if (m.parentId != parentId) m.id];
  List<int> skipped;
  try {
    skipped = await dao.moveModules(todo, nexusRef: nexusId, newParentId: parentId);
  } catch (_) {
    skipped = todo;
  }
  refreshAfterMove(ref, nexusId);
  final moved = todo.length - skipped.length;
  if (moved > 0) messenger.showSnackBar(SnackBar(content: Text(l10n.moveDone.replaceAll('{name}', targetName))));
  if (skipped.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text(l10n.moveIntoSelf)));
}

/// A move changes every list, count and breadcrumb it touches — cheaper to
/// drop the families than to work out which members.
void refreshAfterMove(WidgetRef ref, int nexusId) {
  ref.invalidate(moduleChildrenProvider);
  ref.invalidate(moduleProvider);
  ref.invalidate(moduleBreadcrumbProvider);
  ref.invalidate(pinnedModulesProvider(nexusId));
  ref.invalidate(nexusIndexProvider(nexusId));
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

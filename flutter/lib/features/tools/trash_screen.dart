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
import '../../widgets/confirm_dialog.dart';

final trashProvider = FutureProvider.autoDispose.family<List<TrashEntry>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return TrashService.list(db, nexusId);
});

/// Everything the module tree has refreshed after a trash or a restore.
void refreshAfterTrash(WidgetRef ref, int nexusId) {
  ref.invalidate(trashProvider(nexusId));
  ref.invalidate(nexusIndexProvider(nexusId));
  ref.invalidate(pinnedModulesProvider(nexusId));
  // Any level of the tree may have gained or lost a module.
  ref.invalidate(moduleChildrenProvider);
  ref.invalidate(moduleProvider);
}

/// Restores [trashId] and says so; returns the restored module's id.
Future<int?> restoreFromTrash(WidgetRef ref, int nexusId, int trashId) async {
  final db = await ref.read(databaseProvider.future);
  final id = await TrashService.restore(db, nexusId, trashId);
  refreshAfterTrash(ref, nexusId);
  return id;
}

/// The Trash (V5.md §11.4, EXE hub/trash.js): what was deleted, newest
/// first — restore it, delete it for good, or empty the lot.
class TrashScreen extends ConsumerWidget {
  final int nexusId;
  const TrashScreen({super.key, required this.nexusId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = ref.watch(trashProvider(nexusId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.trashTitle),
        actions: [
          if (items.valueOrNull?.isNotEmpty == true)
            TextButton(
              onPressed: () async {
                if (!await showConfirmDialog(context, title: l.trashEmptyAll, message: l.trashEmptyConfirm)) return;
                final db = await ref.read(databaseProvider.future);
                await TrashService.empty(db, nexusId);
                ref.invalidate(trashProvider(nexusId));
              },
              child: Text(l.trashEmptyAll),
            ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(l.trashNothing, style: theme.textTheme.bodyMedium))
            : ListView(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(l.trashNote, style: theme.textTheme.bodySmall),
                ),
                for (final t in list)
                  ListTile(
                    leading: Icon(moduleKindInfo[ModuleKind.fromId(t.kind)]?.icon ?? Icons.folder_outlined),
                    title: Text(t.name),
                    subtitle: Text([
                      t.deletedAt,
                      if (t.moduleCount > 1) '${t.moduleCount} ${l.trashModules}',
                      if (t.parentName != null) '↑ ${t.parentName}',
                    ].join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: l.trashRestore,
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          final router = GoRouter.of(context);
                          final id = await restoreFromTrash(ref, nexusId, t.id);
                          if (id != null) router.push(RecentView.locationFor(nexusId, id));
                        },
                      ),
                      IconButton(
                        tooltip: l.btnDelete,
                        icon: const Icon(Icons.delete_forever_outlined),
                        onPressed: () async {
                          if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.trashDeleteForever)) return;
                          final db = await ref.read(databaseProvider.future);
                          await TrashService.delete(db, nexusId, t.id);
                          ref.invalidate(trashProvider(nexusId));
                        },
                      ),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/assets/asset_store.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/row_menu.dart';
import '../hub/widgets/move_to_sheet.dart';
import 'assets_screen.dart';

/// The files filed directly in one folder (V5.md §2: the module tree IS the
/// asset tree) — shown under a Collector's modules the way a Unity Project
/// window shows a folder's assets beside its sub-folders.
final moduleAssetsProvider = FutureProvider.autoDispose.family<List<Asset>, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  return AssetStore.ofModule(db, moduleId);
});

/// Asks where, then files [a] there (top level = back to the unfiled tray).
Future<void> moveAssetWithPicker(BuildContext context, WidgetRef ref, int nexusId, Asset a) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final target = await showMoveToSheet(context, nexusId: nexusId, startAt: a.moduleRef);
  if (target == null) return;
  final db = await ref.read(databaseProvider.future);
  await AssetStore.setModule(db, a.id, target.parentId);
  if (a.moduleRef != null) ref.invalidate(moduleAssetsProvider(a.moduleRef!));
  if (target.parentId != null) ref.invalidate(moduleAssetsProvider(target.parentId!));
  ref.invalidate(assetsProvider(nexusId));
  ref.invalidate(nexusIndexProvider(nexusId));
  messenger.showSnackBar(SnackBar(content: Text(l10n.moveDone.replaceAll('{name}', target.name))));
}

/// The "Files" group of a folder's page; nothing at all when it has none.
class FolderAssets extends ConsumerWidget {
  final int nexusId;
  final int moduleId;
  const FolderAssets({super.key, required this.nexusId, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final list = ref.watch(moduleAssetsProvider(moduleId)).valueOrNull ?? const <Asset>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.folderFiles, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final a in list)
          ListTile(
            leading: AssetThumb(asset: a, size: 40),
            title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(a.isUrl ? a.path : '${a.type.toUpperCase()} · ${fileSize(a.size)}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: RowMenuButton(title: a.name, actions: () => _actions(context, ref, a)),
            onLongPress: () => showRowMenu(context, _actions(context, ref, a), title: a.name),
          ),
      ],
    );
  }

  List<RowAction> _actions(BuildContext context, WidgetRef ref, Asset a) {
    final l10n = AppLocalizations.of(context)!;
    return [
      RowAction(
        label: l10n.moveTo,
        icon: Icons.drive_file_move_outline,
        onTap: () => moveAssetWithPicker(context, ref, nexusId, a),
      ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/tokens.g.dart';
import '../../../data/models/module_model.dart';
import '../../../data/services/asset_pack.dart';
import '../../../providers/builder_view_provider.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_provider.dart';
import '../../../providers/recent_views_provider.dart';
import '../../../widgets/color_dot.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/ddx_list.dart';
import '../../../widgets/row_menu.dart';
import '../dialogs/nexus_dialog.dart';
import '../../../widgets/ddx_glass.dart';
import '../../../widgets/ddx_card.dart';

/// The Builder's top level: every Nexus, laid out per the page's view mode.
/// Its menu lives here rather than on the screen so the tile and the card
/// share one — reached by a long press or the row's ⋮ (APP docs/APK-V3.md §5).
class NexusCollectionView extends StatelessWidget {
  final List<NexusModel> nexuses;
  final BuilderViewMode mode;

  const NexusCollectionView({super.key, required this.nexuses, required this.mode});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case BuilderViewMode.grid:
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            // Wider tiles on a tablet: the phone's 170 across an iPad reads
            // as a phone screenshot scaled up rather than a tablet layout.
            maxCrossAxisExtent: gridTileExtentFor(ddxLayoutOf(context)),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: nexuses.length,
          itemBuilder: (_, i) => _NexusCard(nexus: nexuses[i]),
        );
      case BuilderViewMode.compact:
        return ListView.builder(
          itemCount: nexuses.length,
          itemBuilder: (_, i) => _NexusRow(nexus: nexuses[i], density: DdxDensity.compact),
        );
      case BuilderViewMode.list:
        return ListView.separated(
          itemCount: nexuses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _NexusRow(nexus: nexuses[i]),
        );
    }
  }
}

/// Open, rename, export and delete, shared by the row, the card and — with
/// [onOwnPage], which leaves "open" out and walks back to the Nexus list
/// after a delete — the Nexus page's own ⋮.
List<RowAction> nexusActions(BuildContext context, WidgetRef ref, NexusModel nexus, {bool onOwnPage = false}) {
  final l10n = AppLocalizations.of(context)!;
  return [
    if (!onOwnPage) RowAction(label: l10n.rowOpen, icon: Icons.open_in_new, onTap: () => context.push('/hub/${nexus.id}')),
    RowAction(
      label: l10n.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        await showDdxDialog(context: context, builder: (_) => NexusDialog(existing: nexus));
        ref.invalidate(nexusesProvider);
        ref.invalidate(nexusProvider(nexus.id));
      },
    ),
    // The whole Nexus, folders and files, for the desktop (ASSET-PACK.md).
    RowAction(
      label: l10n.exportDxpack,
      icon: Icons.ios_share,
      onTap: () => _exportPack(context, ref, nexus),
    ),
    RowAction(
      label: l10n.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () => _deleteNexus(context, ref, nexus, onOwnPage: onOwnPage),
    ),
  ];
}

Future<void> _exportPack(BuildContext context, WidgetRef ref, NexusModel nexus) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final db = await ref.read(databaseProvider.future);
  final pack = await AssetPack.export(db, nexus.id);
  if (pack == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailedMessage)));
    return;
  }
  if (pack.missing > 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportMediaMissing.replaceAll('{n}', '${pack.missing}'))));
  }
  final name = '${dirNameOf(nexus.name)}.dxpack';
  await Share.shareXFiles([XFile.fromData(pack.bytes, mimeType: 'application/zip', name: name)]);
}

Future<void> _deleteNexus(BuildContext context, WidgetRef ref, NexusModel nexus, {bool onOwnPage = false}) async {
  final l10n = AppLocalizations.of(context)!;
  final router = GoRouter.of(context);
  final ok = await showConfirmDialog(
    context,
    title: '${l10n.confirmDeleteTitle}: "${nexus.name}"',
    message: l10n.deleteNexusMessage,
  );
  if (!ok) return;
  await ref.read(moduleDaoProvider).valueOrNull?.deleteNexus(nexus.id);
  // Every open page inside this Nexus now points at nothing.
  await ref.read(recentViewsProvider.notifier).removeForNexus(nexus.id);
  ref.invalidate(nexusesProvider);
  if (onOwnPage) router.go('/');
}

/// A Nexus as a list row: its colour, its name, its memo as the meta.
class _NexusRow extends ConsumerWidget {
  final NexusModel nexus;
  final DdxDensity density;

  const _NexusRow({required this.nexus, this.density = DdxDensity.comfortable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = density == DdxDensity.compact;
    return DdxListTile(
      density: density,
      leading: nexus.colorCode != null
          ? ColorDot(colorCode: nexus.colorCode, size: compact ? DdxSize.iconSm : DdxSize.iconMd)
          : Icon(Icons.workspaces_outlined, size: compact ? DdxSize.iconSm : DdxSize.iconMd),
      title: nexus.name,
      meta: compact ? null : nexus.memo,
      actions: () => nexusActions(context, ref, nexus),
      onTap: () => context.push('/hub/${nexus.id}'),
    );
  }
}

class _NexusCard extends ConsumerWidget {
  final NexusModel nexus;

  const _NexusCard({required this.nexus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasMemo = nexus.memo != null && nexus.memo!.isNotEmpty;
    List<RowAction> actions() => nexusActions(context, ref, nexus);

    return DdxCard(
      kind: DdxCardKind.link,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/hub/${nexus.id}'),
        onLongPress: () => showRowMenu(context, actions(), title: nexus.name),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  nexus.colorCode != null
                      ? ColorDot(colorCode: nexus.colorCode, size: 26)
                      : Icon(Icons.workspaces_outlined, size: 26, color: theme.colorScheme.primary),
                  const Spacer(),
                  RowMenuButton(actions: actions, title: nexus.name, iconSize: 18),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nexus.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (hasMemo) ...[
                      const SizedBox(height: 4),
                      Text(
                        nexus.memo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

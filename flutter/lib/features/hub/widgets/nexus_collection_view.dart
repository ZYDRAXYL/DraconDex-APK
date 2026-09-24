import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/builder_view_provider.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_provider.dart';
import '../../../providers/recent_views_provider.dart';
import '../../../widgets/color_dot.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/row_menu.dart';
import '../dialogs/nexus_dialog.dart';

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
          itemBuilder: (_, i) => _NexusTile(nexus: nexuses[i], dense: true),
        );
      case BuilderViewMode.list:
        return ListView.separated(
          itemCount: nexuses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _NexusTile(nexus: nexuses[i]),
        );
    }
  }
}

/// Open, rename and delete, shared by both the row and the card.
List<RowAction> _nexusActions(BuildContext context, WidgetRef ref, NexusModel nexus) {
  final l10n = AppLocalizations.of(context)!;
  return [
    RowAction(label: l10n.rowOpen, icon: Icons.open_in_new, onTap: () => context.push('/hub/${nexus.id}')),
    RowAction(
      label: l10n.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        await showDialog(context: context, builder: (_) => NexusDialog(existing: nexus));
        ref.invalidate(nexusesProvider);
        ref.invalidate(nexusProvider(nexus.id));
      },
    ),
    RowAction(
      label: l10n.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () => _deleteNexus(context, ref, nexus),
    ),
  ];
}

Future<void> _deleteNexus(BuildContext context, WidgetRef ref, NexusModel nexus) async {
  final l10n = AppLocalizations.of(context)!;
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
}

class _NexusTile extends ConsumerWidget {
  final NexusModel nexus;
  final bool dense;

  const _NexusTile({required this.nexus, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMemo = nexus.memo != null && nexus.memo!.isNotEmpty;
    List<RowAction> actions() => _nexusActions(context, ref, nexus);
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: nexus.colorCode != null
          ? ColorDot(colorCode: nexus.colorCode, size: 20)
          : const Icon(Icons.workspaces_outlined),
      title: Text(nexus.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: !dense && hasMemo ? Text(nexus.memo!) : null,
      trailing: RowMenuButton(actions: actions, title: nexus.name),
      onTap: () => context.push('/hub/${nexus.id}'),
      onLongPress: () => showRowMenu(context, actions(), title: nexus.name),
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
    List<RowAction> actions() => _nexusActions(context, ref, nexus);

    return Card(
      clipBehavior: Clip.antiAlias,
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

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
import '../dialogs/nexus_dialog.dart';

/// The Builder's top level: every Nexus, laid out per the Navibar's view
/// mode. Rename/delete live here rather than on the screen so the tile and
/// the card share one menu.
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

/// Rename/delete, shared by both the row and the card.
Future<void> _onNexusAction(BuildContext context, WidgetRef ref, NexusModel nexus, String action) async {
  final l10n = AppLocalizations.of(context)!;
  if (action == 'rename') {
    await showDialog(context: context, builder: (_) => NexusDialog(existing: nexus));
    ref.invalidate(nexusesProvider);
  } else if (action == 'delete') {
    final ok = await showConfirmDialog(
      context,
      title: '${l10n.confirmDeleteTitle}: "${nexus.name}"',
      message: l10n.deleteNexusMessage,
    );
    if (!ok) return;
    await ref.read(moduleDaoProvider).when(
      data: (d) => d.deleteNexus(nexus.id),
      loading: () async {},
      error: (_, _) async {},
    );
    // Every folder-views entry under this Nexus now points at nothing.
    await ref.read(recentViewsProvider.notifier).removeForNexus(nexus.id);
    ref.invalidate(nexusesProvider);
  }
}

List<PopupMenuEntry<String>> _nexusMenuItems(AppLocalizations l10n) => [
      PopupMenuItem(value: 'rename', child: Text(l10n.btnRename)),
      PopupMenuItem(value: 'delete', child: Text(l10n.btnDelete)),
    ];

class _NexusTile extends ConsumerWidget {
  final NexusModel nexus;
  final bool dense;

  const _NexusTile({required this.nexus, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasMemo = nexus.memo != null && nexus.memo!.isNotEmpty;
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: nexus.colorCode != null
          ? ColorDot(colorCode: nexus.colorCode, size: 20)
          : const Icon(Icons.workspaces_outlined),
      title: Text(nexus.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: !dense && hasMemo ? Text(nexus.memo!) : null,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _onNexusAction(context, ref, nexus, v),
        itemBuilder: (_) => _nexusMenuItems(l10n),
      ),
      onTap: () => context.push('/hub/${nexus.id}'),
    );
  }
}

class _NexusCard extends ConsumerWidget {
  final NexusModel nexus;

  const _NexusCard({required this.nexus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasMemo = nexus.memo != null && nexus.memo!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/hub/${nexus.id}'),
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
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (v) => _onNexusAction(context, ref, nexus, v),
                    itemBuilder: (_) => _nexusMenuItems(l10n),
                  ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/builder_view_provider.dart';
import '../../../widgets/color_dot.dart';

/// The modules nested at one level of the tree, laid out the way the Builder
/// Navibar's view button says to. Every mode navigates the same way — only
/// the density and shape of a row change.
class ModuleCollectionView extends StatelessWidget {
  final int nexusId;
  final List<ModuleModel> modules;
  final BuilderViewMode mode;

  const ModuleCollectionView({
    super.key,
    required this.nexusId,
    required this.modules,
    required this.mode,
  });

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
          itemCount: modules.length,
          itemBuilder: (_, i) => ModuleCard(nexusId: nexusId, module: modules[i]),
        );
      case BuilderViewMode.compact:
        return ListView.builder(
          itemCount: modules.length,
          itemBuilder: (_, i) => ModuleTile(nexusId: nexusId, module: modules[i], dense: true),
        );
      case BuilderViewMode.list:
        return ListView.separated(
          itemCount: modules.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => ModuleTile(nexusId: nexusId, module: modules[i]),
        );
    }
  }
}

class ModuleTile extends StatelessWidget {
  final int nexusId;
  final ModuleModel module;
  final bool dense;

  const ModuleTile({super.key, required this.nexusId, required this.module, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final info = module.kindInfo;
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      leading: module.colorCode != null ? ColorDot(colorCode: module.colorCode, size: 20) : Icon(info.icon),
      title: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: dense
          ? null
          : Text(info.label + (module.childCount != null && module.childCount! > 0 ? ' · ${module.childCount} inside' : '')),
      trailing: module.pinned
          ? const Icon(Icons.push_pin, size: 18)
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/hub/$nexusId/module/${module.id}'),
    );
  }
}

class ModuleCard extends StatelessWidget {
  final int nexusId;
  final ModuleModel module;

  const ModuleCard({super.key, required this.nexusId, required this.module});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = module.kindInfo;
    final childCount = module.childCount ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/hub/$nexusId/module/${module.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  module.colorCode != null
                      ? ColorDot(colorCode: module.colorCode, size: 26)
                      : Icon(info.icon, size: 26, color: theme.colorScheme.primary),
                  const Spacer(),
                  if (module.pinned) const Icon(Icons.push_pin, size: 16),
                ],
              ),
              const Spacer(),
              Text(
                module.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (childCount > 0) ...[
                    Icon(Icons.folder_outlined,
                        size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 2),
                    Text('$childCount', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

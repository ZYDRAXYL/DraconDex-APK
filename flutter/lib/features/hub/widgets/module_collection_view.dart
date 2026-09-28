import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/builder_view_provider.dart';
import '../../../providers/module_provider.dart';
import '../../../core/theme/ddx_theme.dart';
import '../../../widgets/color_dot.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/row_menu.dart';
import '../module_actions.dart';
import 'module_drag.dart';

/// The modules nested at one level of the tree, laid out the way the page's
/// view-mode button says to. Every mode navigates the same way — only the
/// density and shape of a row change — and every row has its menu two ways:
/// a long press and a ⋮ (APP docs/APK-V3.md §5).
class ModuleCollectionView extends StatelessWidget {
  final int nexusId;
  final List<ModuleModel> modules;
  final BuilderViewMode mode;

  /// Inside a page's own scroll view: sizes to its rows and leaves the
  /// scrolling to the page.
  final bool embedded;

  const ModuleCollectionView({
    super.key,
    required this.nexusId,
    required this.modules,
    required this.mode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case BuilderViewMode.grid:
        return GridView.builder(
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
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
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          itemCount: modules.length,
          itemBuilder: (_, i) => ModuleTile(nexusId: nexusId, module: modules[i], dense: true),
        );
      case BuilderViewMode.list:
        // iOS: one grouped inset card, separators past the icon square (C3).
        if (context.isIosStyle) {
          final card = DdxGroupedSection(
            separatorIndent: 58,
            children: [for (final m in modules) ModuleTile(nexusId: nexusId, module: m)],
          );
          return embedded
              ? Padding(padding: const EdgeInsets.only(top: 8), child: card)
              : ListView(padding: const EdgeInsets.only(top: 8), children: [card]);
        }
        return ListView.separated(
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          itemCount: modules.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => ModuleTile(nexusId: nexusId, module: modules[i]),
        );
    }
  }
}

class ModuleTile extends ConsumerWidget {
  final int nexusId;
  final ModuleModel module;
  final bool dense;

  const ModuleTile({super.key, required this.nexusId, required this.module, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = module.kindInfo;
    final l10n = AppLocalizations.of(context)!;
    List<RowAction> actions() => moduleRowActions(context, ref, module);
    final ios = context.isIosStyle;
    final sel = _Selection(ref, module);
    final tile = ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : null,
      selected: sel.picked,
      leading: sel.active
          ? Icon(sel.picked ? Icons.check_circle : Icons.radio_button_unchecked)
          : ios
          ? DdxIconSquare(icon: info.icon, color: _iconColor(context, module.colorCode))
          : module.colorCode != null ? ColorDot(colorCode: module.colorCode, size: 20) : Icon(info.icon),
      title: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: dense
          ? null
          : Text(kindName(l10n, module.kind) +
              (module.childCount != null && module.childCount! > 0 ? ' · ${module.childCount} ${l10n.moduleInside}' : '')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (module.pinned) const Icon(Icons.push_pin, size: 16),
          RowMenuButton(actions: actions, title: module.name),
        ],
      ),
      onTap: sel.active ? sel.toggle : () => context.push('/hub/$nexusId/module/${module.id}'),
      onLongPress: sel.active ? sel.toggle : () => showRowMenu(context, actions(), title: module.name),
    );
    if (!ios || sel.active) return draggableModule(nexusId: nexusId, module: module, child: tile);
    // iOS: swipe left runs the row's destructive action — the same one its
    // menu offers, with the same confirmation and undo. The row stays put
    // until that action actually removes it.
    return Dismissible(
      key: ValueKey('swipe-${module.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        for (final a in actions()) {
          if (a.danger) {
            a.onTap();
            break;
          }
        }
        return false;
      },
      child: draggableModule(nexusId: nexusId, module: module, child: tile),
    );
  }
}

/// One row's part in its level's select mode (moduleSelectionProvider).
class _Selection {
  final WidgetRef ref;
  final ModuleChildrenKey key;
  final Set<int> ids;
  final int id;
  _Selection(this.ref, ModuleModel module)
      : key = ModuleChildrenKey(module.nexusRef, module.parentId),
        id = module.id,
        ids = ref.watch(moduleSelectionProvider(ModuleChildrenKey(module.nexusRef, module.parentId)));

  bool get active => ids.isNotEmpty;
  bool get picked => ids.contains(id);
  void toggle() => ref.read(moduleSelectionProvider(key).notifier).state =
      picked ? ({...ids}..remove(id)) : {...ids, id};
}

/// The module's own colour for its iOS icon square, or the accent.
Color _iconColor(BuildContext context, String? code) {
  if (code != null && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(code)) return hexToColor(code);
  return Theme.of(context).colorScheme.primary;
}

class ModuleCard extends ConsumerWidget {
  final int nexusId;
  final ModuleModel module;

  const ModuleCard({super.key, required this.nexusId, required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = module.kindInfo;
    final childCount = module.childCount ?? 0;
    List<RowAction> actions() => moduleRowActions(context, ref, module);
    final sel = _Selection(ref, module);

    return draggableModule(nexusId: nexusId, module: module, child: Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: sel.picked
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: sel.active ? sel.toggle : () => context.push('/hub/$nexusId/module/${module.id}'),
        onLongPress: sel.active ? sel.toggle : () => showRowMenu(context, actions(), title: module.name),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  sel.active
                      ? Icon(sel.picked ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 26, color: theme.colorScheme.primary)
                      : module.colorCode != null
                      ? ColorDot(colorCode: module.colorCode, size: 26)
                      : Icon(info.icon, size: 26, color: theme.colorScheme.primary),
                  const Spacer(),
                  if (module.pinned) const Icon(Icons.push_pin, size: 16),
                  RowMenuButton(actions: actions, title: module.name, iconSize: 18),
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
                      kindName(AppLocalizations.of(context)!, module.kind),
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
    ));
  }
}

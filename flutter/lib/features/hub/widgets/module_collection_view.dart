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

  /// Inside a page's own CustomScrollView: a sliver, so a folder of
  /// hundreds builds only the rows on screen (Procress 19 F5) — the page
  /// does the scrolling.
  final bool sliver;

  const ModuleCollectionView({
    super.key,
    required this.nexusId,
    required this.modules,
    required this.mode,
    this.sliver = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case BuilderViewMode.grid:
        final delegate = SliverGridDelegateWithMaxCrossAxisExtent(
          // Wider tiles on a tablet: the phone's 170 across an iPad reads
          // as a phone screenshot scaled up rather than a tablet layout.
          maxCrossAxisExtent: gridTileExtentFor(ddxLayoutOf(context)),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        );
        Widget card(BuildContext _, int i) => ModuleCard(nexusId: nexusId, module: modules[i]);
        if (sliver) {
          return SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(gridDelegate: delegate, itemCount: modules.length, itemBuilder: card),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: delegate,
          itemCount: modules.length,
          itemBuilder: card,
        );
      case BuilderViewMode.compact:
        Widget tile(BuildContext _, int i) => ModuleTile(nexusId: nexusId, module: modules[i], dense: true);
        if (sliver) return SliverList.builder(itemCount: modules.length, itemBuilder: tile);
        return ListView.builder(itemCount: modules.length, itemBuilder: tile);
      case BuilderViewMode.list:
        Widget tile(BuildContext _, int i) => ModuleTile(nexusId: nexusId, module: modules[i]);
        // iOS: one grouped inset card, separators past the icon square (C3).
        if (context.isIosStyle) {
          final card = DdxGroupedSection.sliver(separatorIndent: 58, itemCount: modules.length, itemBuilder: tile);
          final list = SliverPadding(padding: const EdgeInsets.only(top: 8), sliver: card);
          return sliver ? list : CustomScrollView(slivers: [list]);
        }
        Widget divider(BuildContext _, int i) => const Divider(height: 1);
        if (sliver) return SliverList.separated(itemCount: modules.length, separatorBuilder: divider, itemBuilder: tile);
        return ListView.separated(itemCount: modules.length, separatorBuilder: divider, itemBuilder: tile);
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
/// A row watches only its own two bits, so ticking one row rebuilds that
/// row (and every row only when select mode starts or ends), not the level.
class _Selection {
  final WidgetRef ref;
  final ModuleChildrenKey key;
  final int id;
  final bool active;
  final bool picked;
  _Selection._(this.ref, this.key, this.id, this.active, this.picked);

  factory _Selection(WidgetRef ref, ModuleModel module) {
    final key = ModuleChildrenKey(module.nexusRef, module.parentId);
    final p = moduleSelectionProvider(key);
    return _Selection._(ref, key, module.id, ref.watch(p.select((s) => s.isNotEmpty)), ref.watch(p.select((s) => s.contains(module.id))));
  }

  void toggle() {
    final n = ref.read(moduleSelectionProvider(key).notifier);
    n.state = n.state.contains(id) ? ({...n.state}..remove(id)) : {...n.state, id};
  }
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

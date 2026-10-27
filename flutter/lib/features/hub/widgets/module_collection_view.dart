import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/builder_view_provider.dart';
import '../../../providers/module_provider.dart';
import '../../../core/theme/ddx_theme.dart';
import '../../../core/theme/tokens.g.dart';
import '../../../widgets/color_dot.dart';
import '../../../widgets/ddx_list.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/row_menu.dart';
import '../module_actions.dart';
import 'module_drag.dart';
import '../../../widgets/ddx_card.dart';
import '../../../widgets/ddx_ref_icon.dart';

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
      case BuilderViewMode.details:
        // Procress 29 part 7: a header, then one row per module — the
        // list's own sort (its header above) orders them
        Widget row(BuildContext _, int i) => i == 0 ? const _DetailsHeader() : _DetailsRow(nexusId: nexusId, module: modules[i - 1]);
        if (sliver) return SliverList.builder(itemCount: modules.length + 1, itemBuilder: row);
        return ListView.builder(itemCount: modules.length + 1, itemBuilder: row);
      case BuilderViewMode.compact:
        Widget tile(BuildContext _, int i) => ModuleTile(nexusId: nexusId, module: modules[i], density: DdxDensity.compact);
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

/// A module as a list row ([DdxListTile]) — with what a module row adds:
/// select mode, dragging into a folder, and on iOS swipe-to-delete.
class ModuleTile extends ConsumerWidget {
  final int nexusId;
  final ModuleModel module;
  final DdxDensity density;

  const ModuleTile({super.key, required this.nexusId, required this.module, this.density = DdxDensity.comfortable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = module.kindInfo;
    final l10n = AppLocalizations.of(context)!;
    List<RowAction> actions() => moduleRowActions(context, ref, module);
    final ios = context.isIosStyle;
    final compact = density == DdxDensity.compact;
    final iconSize = compact ? DdxSize.iconSm : DdxSize.iconMd;
    final sel = _Selection(ref, module);
    final tile = DdxListTile(
      density: density,
      selected: sel.picked,
      leading: sel.active
          ? Icon(sel.picked ? Icons.check_circle : Icons.radio_button_unchecked, size: iconSize)
          // Procress 29 part 7: the module's own icon, as the desktop set it
          : DdxRefIcon.draws(module.icon)
          ? DdxRefIcon(module.icon, size: iconSize, color: _iconColor(context, module.iconColorCode ?? module.colorCode), fallback: info.icon)
          : ios && !compact
          ? DdxIconSquare(icon: info.icon, color: _iconColor(context, module.colorCode))
          : module.colorCode != null ? ColorDot(colorCode: module.colorCode, size: iconSize) : Icon(info.icon, size: iconSize),
      title: module.name,
      meta: compact
          ? null
          : kindName(l10n, module.kind) +
              (module.childCount != null && module.childCount! > 0 ? ' · ${module.childCount} ${l10n.moduleInside}' : ''),
      trailing: [if (module.pinned) const Icon(Icons.push_pin, size: DdxSize.iconSm)],
      actions: actions,
      onTap: sel.active ? sel.toggle : () => context.push('/hub/$nexusId/module/${module.id}'),
      // in select mode a long press ticks too; otherwise the row's menu
      onLongPress: sel.active ? sel.toggle : null,
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

    return draggableModule(nexusId: nexusId, module: module, child: DdxCard(
      kind: DdxCardKind.link,
      margin: EdgeInsets.zero,
      selected: sel.picked,
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
                      : DdxRefIcon.draws(module.icon)
                      ? DdxRefIcon(module.icon, size: 26, color: _iconColor(context, module.iconColorCode ?? module.colorCode), fallback: info.icon)
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

// ── Details (Procress 29 part 7) ───────────────────────────────────────────
// Name · kind · updated · items, the desktop folder page's details view.
const _detailsFlex = [5, 3, 3, 2];

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final st = Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final cols = [l.listSortName, l.folderColKind, l.folderColUpdated, l.folderColItems];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(children: [
        for (var i = 0; i < cols.length; i++)
          Expanded(flex: _detailsFlex[i], child: Text(cols[i], style: st, textAlign: i == 3 ? TextAlign.end : TextAlign.start)),
      ]),
    );
  }
}

class _DetailsRow extends ConsumerWidget {
  final int nexusId;
  final ModuleModel module;
  const _DetailsRow({required this.nexusId, required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sel = _Selection(ref, module);
    final dim = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final updated = module.updatedAt.length >= 16 ? module.updatedAt.substring(0, 16).replaceFirst('T', ' ') : module.updatedAt;
    return draggableModule(nexusId: nexusId, module: module, child: InkWell(
      onTap: sel.active ? sel.toggle : () => context.push('/hub/$nexusId/module/${module.id}'),
      onLongPress: sel.active ? sel.toggle : () => showRowMenu(context, moduleRowActions(context, ref, module), title: module.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel.picked ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(children: [
          Expanded(flex: _detailsFlex[0], child: Row(children: [
            DdxRefIcon(module.icon, size: DdxSize.iconSm, fallback: module.kindInfo.icon,
                color: _iconColor(context, module.iconColorCode ?? module.colorCode)),
            const SizedBox(width: 8),
            Expanded(child: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: _detailsFlex[1], child: Text(kindName(l, module.kind), style: dim, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: _detailsFlex[2], child: Text(updated, style: dim, maxLines: 1)),
          Expanded(flex: _detailsFlex[3], child: Text('${module.childCount ?? ''}', style: dim, textAlign: TextAlign.end)),
        ]),
      ),
    ));
  }
}

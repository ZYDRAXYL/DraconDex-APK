import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../core/theme/tokens.g.dart';
import '../../data/models/module_model.dart';
import '../../providers/module_provider.dart';
import '../../providers/shell_layout_provider.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/ddx_list.dart';
import '../../widgets/row_menu.dart';
import '../hub/module_actions.dart';
import '../hub/widgets/module_drag.dart';
import 'hub_location.dart';

/// The nest itself: every Nexus, unfoldable into the module tree under it.
/// Levels below the first are only queried once their parent is opened, so
/// the panel costs one query on a cold start no matter how deep the tree is.
class HubTree extends ConsumerStatefulWidget {
  final String location;

  const HubTree({super.key, required this.location});

  @override
  ConsumerState<HubTree> createState() => _HubTreeState();
}

class _HubTreeState extends ConsumerState<HubTree> {
  /// Unfolds the path down to whatever the content pane is showing, so a jump
  /// from the folder-views list (or a deep link) leaves the tree pointing at
  /// where the user actually is instead of collapsed at the root.
  void _revealCurrent(HubLocation loc) {
    if (loc.nexusId == null) return;
    final keys = <String>[hubNodeKey(loc.nexusId!, null)];
    if (loc.moduleId != null) {
      // Still loading: unfold the Nexus now and pick the rest up on the
      // rebuild the breadcrumb query triggers when it lands.
      final ancestors = ref.watch(moduleBreadcrumbProvider(loc.moduleId!)).valueOrNull;
      if (ancestors != null) {
        keys.addAll(ancestors.map((m) => hubNodeKey(loc.nexusId!, m.id)));
      }
    }
    // expand() is a no-op when nothing new is added, so this cannot loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(hubTreeExpansionProvider.notifier).expand(keys);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loc = HubLocation.parse(widget.location);
    _revealCurrent(loc);

    final nexusesAsync = ref.watch(nexusesProvider);
    return nexusesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('$e', style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (nexuses) {
        if (nexuses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l10n.emptyNexusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final nexus in nexuses) _NexusNode(nexus: nexus, current: loc),
          ],
        );
      },
    );
  }
}

class _NexusNode extends ConsumerWidget {
  final NexusModel nexus;
  final HubLocation current;

  const _NexusNode({required this.nexus, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = hubNodeKey(nexus.id, null);
    // only this node's own bit: expanding another node does not rebuild it
    final expanded = ref.watch(hubTreeExpansionProvider.select((s) => s.contains(key)));
    final selected = current.nexusId == nexus.id && current.moduleId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The Nexus's top level takes a dropped module too, out of any folder.
        FolderDropTarget(nexusId: nexus.id, folderId: null, folderName: nexus.name, child: DdxListTile(
          density: DdxDensity.compact,
          selected: selected,
          leading: _Twisty(
            expanded: expanded,
            onToggle: () => ref.read(hubTreeExpansionProvider.notifier).toggle(key),
            child: nexus.colorCode != null
                ? ColorDot(colorCode: nexus.colorCode, size: DdxSize.iconSm)
                : const Icon(Icons.workspaces_outlined, size: DdxSize.iconSm),
          ),
          title: nexus.name,
          onTap: () {
            ref.read(hubTreeExpansionProvider.notifier).expand([key]);
            context.go('/hub/${nexus.id}');
          },
        )),
        if (expanded)
          _ChildLevel(nexusId: nexus.id, parentId: null, depth: 1, current: current),
      ],
    );
  }
}

/// One level of modules under [parentId], fetched only while it is on screen.
class _ChildLevel extends ConsumerWidget {
  final int nexusId;
  final int? parentId;
  final int depth;
  final HubLocation current;

  const _ChildLevel({
    required this.nexusId,
    required this.parentId,
    required this.depth,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(moduleChildrenProvider(ModuleChildrenKey(nexusId, parentId)));
    return childrenAsync.when(
      loading: () => const SizedBox(height: 4),
      error: (_, _) => const SizedBox.shrink(),
      data: (modules) {
        if (modules.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final module in modules)
              _ModuleNode(nexusId: nexusId, module: module, depth: depth, current: current),
          ],
        );
      },
    );
  }
}

class _ModuleNode extends ConsumerWidget {
  final int nexusId;
  final ModuleModel module;
  final int depth;
  final HubLocation current;

  const _ModuleNode({
    required this.nexusId,
    required this.module,
    required this.depth,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = hubNodeKey(nexusId, module.id);
    // only this node's own bit: expanding another node does not rebuild it
    final expanded = ref.watch(hubTreeExpansionProvider.select((s) => s.contains(key)));
    final selected = current.nexusId == nexusId && current.moduleId == module.id;
    final hasChildren = (module.childCount ?? 0) > 0;
    List<RowAction> actions() => moduleRowActions(context, ref, module, inTree: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        draggableModule(nexusId: nexusId, module: module, child: DdxListTile(
          density: DdxDensity.compact,
          // Indent stops growing past eight levels: a deeper nest would
          // otherwise push the name off the edge of a narrow panel entirely.
          indent: math.min(depth, 8) * DdxSpace.sp6,
          selected: selected,
          leading: _Twisty(
            expanded: expanded,
            onToggle: hasChildren ? () => ref.read(hubTreeExpansionProvider.notifier).toggle(key) : null,
            child: module.colorCode != null
                ? ColorDot(colorCode: module.colorCode, size: DdxSize.iconSm)
                : Icon(module.kindInfo.icon, size: DdxSize.iconSm),
          ),
          title: module.name,
          trailing: [if (module.pinned) const Icon(Icons.push_pin, size: DdxSize.iconSm)],
          actions: actions,
          onTap: () {
            if (hasChildren) ref.read(hubTreeExpansionProvider.notifier).expand([key]);
            context.go('/hub/$nexusId/module/${module.id}');
          },
        )),
        if (expanded && hasChildren)
          _ChildLevel(nexusId: nexusId, parentId: module.id, depth: depth + 1, current: current),
      ],
    );
  }
}

/// A tree row's leading: the twisty (empty space on a leaf, so names line
/// up), then the row's own icon.
class _Twisty extends StatelessWidget {
  final bool expanded;
  final VoidCallback? onToggle;
  final Widget child;

  const _Twisty({required this.expanded, required this.onToggle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: DdxSize.ctlSm,
        child: onToggle == null
            ? null
            : InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(DdxRadius.rs),
                child: Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: DdxSize.iconMd,
                  color: context.ddx.textMuted,
                ),
              ),
      ),
      child,
    ]);
  }
}

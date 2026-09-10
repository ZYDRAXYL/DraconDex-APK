import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../providers/module_provider.dart';
import '../../providers/shell_layout_provider.dart';
import '../../widgets/color_dot.dart';
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
    final expanded = ref.watch(hubTreeExpansionProvider).contains(key);
    final selected = current.nexusId == nexus.id && current.moduleId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeRow(
          depth: 0,
          expanded: expanded,
          hasChildren: true,
          selected: selected,
          leading: nexus.colorCode != null
              ? ColorDot(colorCode: nexus.colorCode, size: 16)
              : const Icon(Icons.workspaces_outlined, size: 16),
          label: nexus.name,
          onToggle: () => ref.read(hubTreeExpansionProvider.notifier).toggle(key),
          onTap: () {
            ref.read(hubTreeExpansionProvider.notifier).expand([key]);
            context.go('/hub/${nexus.id}');
          },
        ),
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
    final expanded = ref.watch(hubTreeExpansionProvider).contains(key);
    final selected = current.nexusId == nexusId && current.moduleId == module.id;
    final hasChildren = (module.childCount ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeRow(
          depth: depth,
          expanded: expanded,
          hasChildren: hasChildren,
          selected: selected,
          leading: module.colorCode != null
              ? ColorDot(colorCode: module.colorCode, size: 16)
              : Icon(module.kindInfo.icon, size: 16),
          label: module.name,
          trailing: module.pinned ? const Icon(Icons.push_pin, size: 13) : null,
          onToggle: hasChildren
              ? () => ref.read(hubTreeExpansionProvider.notifier).toggle(key)
              : null,
          onTap: () {
            if (hasChildren) ref.read(hubTreeExpansionProvider.notifier).expand([key]);
            context.go('/hub/$nexusId/module/${module.id}');
          },
        ),
        if (expanded && hasChildren)
          _ChildLevel(nexusId: nexusId, parentId: module.id, depth: depth + 1, current: current),
      ],
    );
  }
}

/// One row of the tree at any depth — the twisty, the icon and the name, with
/// the same left accent bar the desktop build marks an open item with.
class _TreeRow extends StatelessWidget {
  final int depth;
  final bool expanded;
  final bool hasChildren;
  final bool selected;
  final Widget leading;
  final String label;
  final Widget? trailing;
  final VoidCallback? onToggle;
  final VoidCallback onTap;

  const _TreeRow({
    required this.depth,
    required this.expanded,
    required this.hasChildren,
    required this.selected,
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                border: Border(left: BorderSide(color: scheme.primary, width: 3)),
              )
            : null,
        // Indent stops growing past eight levels: a deeper nest would other-
        // wise push the name off the edge of a narrow panel entirely.
        padding: EdgeInsets.only(
          left: 6.0 + math.min(depth, 8) * 14,
          right: 8,
          top: 5,
          bottom: 5,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: hasChildren
                  ? InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
            ),
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

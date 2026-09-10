import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/recent_views_provider.dart';
import '../../providers/shell_layout_provider.dart';
import '../../widgets/color_dot.dart';
import 'hub_tree.dart';

/// The tablet shell's hub panel — the Electron build's `#left-panel` on a
/// touch screen: the whole Nexus nest as one tree you can walk without
/// leaving the module you are reading, plus the folder-views history that the
/// phone can only show as a sheet.
///
/// Rows navigate with `go`, not `push`: this is a place-picker sitting beside
/// the content, so choosing a place *replaces* what the content pane shows
/// instead of stacking another screen on top of it. The nested routes still
/// give the pane's back button a parent to walk up to.
class HubSidebar extends ConsumerWidget {
  final String location;

  /// Dismisses the panel — hides the column on a wide window, closes the
  /// drawer on a narrow one. Null hides the button entirely.
  final VoidCallback? onClose;

  const HubSidebar({super.key, required this.location, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shell = ref.watch(shellLayoutProvider);
    final notifier = ref.read(shellLayoutProvider.notifier);
    final recentCount = ref.watch(recentViewsProvider).length;

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHead(title: l10n.hubNestTitle, onClose: onClose),
              // Folder views sits above the tree, not below it: under a nest
              // of any size its header would be scrolled off the bottom
              // exactly when the user wants it. Collapsed it costs one row.
              _SectionHeader(
                label: l10n.recentViewsTitle,
                icon: Icons.folder_copy_outlined,
                open: shell.recentSectionOpen,
                badgeCount: recentCount,
                onToggle: () => notifier.setRecentSectionOpen(!shell.recentSectionOpen),
              ),
              if (shell.recentSectionOpen)
                ConstrainedBox(
                  // Capped so twenty remembered places cannot push the tree
                  // off the panel; the list scrolls inside the cap.
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: const SingleChildScrollView(child: _RecentSection()),
                ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: HubTree(location: location),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The draggable edge between the hub panel and the content pane. Only the
/// wide shell shows one — over a drawer there is nothing to resize.
class HubResizeHandle extends ConsumerWidget {
  const HubResizeHandle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(shellLayoutProvider.notifier);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          notifier.setHubWidth(ref.read(shellLayoutProvider).hubWidth + d.delta.dx);
        },
        // One preference write per drag, not one per frame.
        onHorizontalDragEnd: (_) => notifier.commitHubWidth(),
        child: const SizedBox(width: 8, height: double.infinity),
      ),
    );
  }
}

class _PanelHead extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const _PanelHead({required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              tooltip: AppLocalizations.of(context)!.hubPanelHide,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool open;
  final VoidCallback onToggle;
  final int badgeCount;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.open,
    required this.onToggle,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
        child: Row(
          children: [
            Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18),
            const SizedBox(width: 2),
            Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (badgeCount > 0)
              Text('$badgeCount', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// The folder-views history, inline in the panel instead of in the phone's
/// bottom sheet — on a tablet it can simply stay open next to the content.
class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final views = ref.watch(recentViewsProvider);

    if (views.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(l10n.recentViewsEmpty, style: theme.textTheme.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final view in views) _RecentRow(view: view),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => ref.read(recentViewsProvider.notifier).clear(),
            child: Text(l10n.recentViewsClear),
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends ConsumerWidget {
  final RecentView view;

  const _RecentRow({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kind = view.kind;
    final icon = kind == null ? Icons.workspaces_outlined : moduleKindInfo[kind]!.icon;

    return InkWell(
      onTap: () => context.go(view.location),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
        child: Row(
          children: [
            view.colorCode != null
                ? ColorDot(colorCode: view.colorCode, size: 16)
                : Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              visualDensity: VisualDensity.compact,
              tooltip: AppLocalizations.of(context)!.btnDelete,
              onPressed: () => ref.read(recentViewsProvider.notifier).remove(view.key),
            ),
          ],
        ),
      ),
    );
  }
}

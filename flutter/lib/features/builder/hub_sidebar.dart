import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../providers/shell_layout_provider.dart';
import 'hub_tree.dart';

/// The tablet shell's hub panel — the Electron build's `#left-panel` on a
/// touch screen: the whole Nexus nest as one tree you can walk without
/// leaving the module you are reading. The pages the user has open are the
/// tab row above the content (open_pages_bar.dart), not a section here.
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

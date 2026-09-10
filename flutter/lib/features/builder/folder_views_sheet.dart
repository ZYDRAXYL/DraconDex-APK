import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/color_dot.dart';

/// The Navibar's "folder views" button: every place the app was recently
/// opened at, newest first, so the user can drop straight back into the view
/// they were last in instead of drilling the tree again.
Future<void> showFolderViewsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _FolderViewsSheet(),
  );
}

class _FolderViewsSheet extends ConsumerWidget {
  const _FolderViewsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(recentViewsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Half-height by default so the sheet reads as a panel over the
        // current screen, not a full takeover of it.
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.recentViewsTitle, style: theme.textTheme.titleMedium),
                  ),
                  if (views.isNotEmpty)
                    TextButton(
                      onPressed: () => ref.read(recentViewsProvider.notifier).clear(),
                      child: Text(l10n.recentViewsClear),
                    ),
                ],
              ),
            ),
            if (views.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Text(
                  l10n.recentViewsEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: views.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RecentViewTile(view: views[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentViewTile extends ConsumerWidget {
  final RecentView view;

  const _RecentViewTile({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final kind = view.kind;
    final kindLabel = kind == null ? l10n.builderNexusRootLabel : moduleKindInfo[kind]!.label;
    final icon = kind == null ? Icons.workspaces_outlined : moduleKindInfo[kind]!.icon;
    final subtitle = view.moduleId == null || view.nexusName.isEmpty
        ? kindLabel
        : '${view.nexusName} · $kindLabel';

    return ListTile(
      leading: view.colorCode != null ? ColorDot(colorCode: view.colorCode, size: 20) : Icon(icon),
      title: Text(view.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: l10n.btnDelete,
        onPressed: () => ref.read(recentViewsProvider.notifier).remove(view.key),
      ),
      onTap: () {
        // Grab the router before popping — this tile's context is gone by the
        // time the sheet route finishes closing.
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go(view.location);
      },
    );
  }
}

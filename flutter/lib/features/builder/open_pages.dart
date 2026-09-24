import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/color_dot.dart';

/// The pages the user has open (APK V3, APP docs/APK-V3.md §10.2), drawn two
/// ways from one list ([recentViewsProvider]):
///
///  * phone — the Navibar's "open pages" button opens [showOpenPagesSheet], a
///    card switcher like a mobile browser's tabs: tap a card to go there,
///    swipe it away to close it;
///  * tablet — [OpenPagesBar], a row of tabs across the top of the content
///    pane. Android has no frameless title bar to put them on the way the
///    desktop app does (V5.md §12.7), so "on the title bar" becomes "the top
///    row".

IconData _iconOf(RecentView view) {
  final kind = view.kind;
  if (kind == null) return Icons.workspaces_outlined;
  if (view.itemKey != null) return Icons.article_outlined;
  return moduleKindInfo[kind]!.icon;
}

Widget _leadingOf(RecentView view, {double size = 18}) => view.colorCode != null && view.itemKey == null
    ? ColorDot(colorCode: view.colorCode, size: size)
    : Icon(_iconOf(view), size: size);

/// Closes [view]. Closing the page on screen goes to its neighbour in the
/// tab order — the next one, else the one before, else the Nexus list — the
/// way closing a browser's current tab does; otherwise the screen would keep
/// showing a page that is no longer open anywhere.
void closeOpenPage(WidgetRef ref, GoRouter router, RecentView view, {required bool current}) {
  if (current) {
    final views = ref.read(recentViewsProvider);
    final i = views.indexWhere((v) => v.key == view.key);
    final next = i + 1 < views.length ? views[i + 1] : (i > 0 ? views[i - 1] : null);
    router.go(next?.location ?? '/');
  }
  ref.read(recentViewsProvider.notifier).close(view.key);
}

/// The phone's card switcher. [currentLocation] marks the page on screen.
Future<void> showOpenPagesSheet(BuildContext context, {required String currentLocation}) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the Navibar, not under it: the shell's own navigator sits
    // above the bar, so a sheet opened on it would be cut off by it.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _OpenPagesSheet(currentLocation: currentLocation),
  );
}

class _OpenPagesSheet extends ConsumerWidget {
  final String currentLocation;

  const _OpenPagesSheet({required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final views = RecentViewsNotifier.byRecency(ref.watch(recentViewsProvider));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.openPagesTitle, style: theme.textTheme.titleMedium)),
                  if (views.isNotEmpty)
                    TextButton(
                      onPressed: () => ref.read(recentViewsProvider.notifier).clear(),
                      child: Text(l10n.openPagesCloseAll),
                    ),
                ],
              ),
            ),
            if (views.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Text(
                  l10n.openPagesEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: views.length,
                  itemBuilder: (_, i) => _PageCard(
                    key: ValueKey(views[i].key),
                    view: views[i],
                    current: views[i].location == currentLocation,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageCard extends ConsumerWidget {
  final RecentView view;
  final bool current;

  const _PageCard({super.key, required this.view, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = view.kind;
    final kindLabel = kind == null ? l10n.builderNexusRootLabel : kindName(l10n, kind);
    final subtitle = view.moduleId == null || view.nexusName.isEmpty ? kindLabel : '${view.nexusName} · $kindLabel';
    void close() => closeOpenPage(ref, GoRouter.of(context), view, current: current);

    return Dismissible(
      key: ValueKey('dismiss-${view.key}'),
      onDismissed: (_) => close(),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: current ? scheme.primary : theme.dividerColor, width: current ? 2 : 1),
        ),
        child: InkWell(
          onTap: () {
            // Grab the router before popping — this card's context is gone by
            // the time the sheet route finishes closing.
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go(view.location);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _leadingOf(view, size: 22),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.openPageClose,
                      onPressed: close,
                    ),
                  ],
                ),
                const Spacer(),
                Text(view.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tablet's tab row, above the content pane. Absent while nothing is
/// open, so the Nexus list on a fresh install does not start with an empty
/// strip.
class OpenPagesBar extends ConsumerWidget {
  final String location;

  const OpenPagesBar({super.key, required this.location});

  static const double height = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(recentViewsProvider);
    if (views.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Container(
        height: height,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
        child: SafeArea(
          bottom: false,
          left: false,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: views.length,
            itemBuilder: (_, i) => _PageTab(view: views[i], current: views[i].location == location),
          ),
        ),
      ),
    );
  }
}

class _PageTab extends ConsumerWidget {
  final RecentView view;
  final bool current;

  const _PageTab({required this.view, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = current ? scheme.primary : scheme.onSurface.withValues(alpha: 0.8);

    return InkWell(
      onTap: () => context.go(view.location),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
        decoration: BoxDecoration(
          color: current ? scheme.surface : null,
          border: Border(
            right: BorderSide(color: theme.dividerColor),
            bottom: BorderSide(color: current ? scheme.primary : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _leadingOf(view, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: current ? FontWeight.w600 : null,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              visualDensity: VisualDensity.compact,
              tooltip: AppLocalizations.of(context)!.openPageClose,
              onPressed: () => closeOpenPage(ref, GoRouter.of(context), view, current: current),
            ),
          ],
        ),
      ),
    );
  }
}

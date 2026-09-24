import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/models/viewer_model.dart';
import '../../data/services/search_service.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/color_dot.dart';

/// One segment of the breadcrumb: the Nexus, a module, or an element.
class Crumb {
  final String label;
  final int nexusId;

  /// null for the Nexus segment.
  final int? moduleId;

  /// Set for the element segment only.
  final String? itemKey;

  const Crumb({required this.label, required this.nexusId, this.moduleId, this.itemKey});

  String get location => RecentView.locationFor(nexusId, moduleId, itemKey);
}

/// The segments a title shows when there are more than [keep]: the last
/// [keep] stay, the ones before them fold into a leading "…" (APP
/// docs/APK-V3.md §10.3 — the start of a long path is trimmed, never its
/// end, because the end is where the user is).
({List<T> hidden, List<T> shown}) trimCrumbs<T>(List<T> crumbs, {int keep = 3}) {
  if (crumbs.length <= keep) return (hidden: <T>[], shown: crumbs);
  final cut = crumbs.length - keep;
  return (hidden: crumbs.sublist(0, cut), shown: crumbs.sublist(cut));
}

/// The page's address as its app-bar title — `World › Characters › Arin`
/// (APK V3, APP docs/APK-V3.md §10.3, §13 item 4). The desktop's address row
/// (EXE page/address.js) translated to touch:
///
///  * **tap a segment** — a sheet of what is inside it (for the last one,
///    its elements too), plus the segment's own page when it is not this one;
///  * **long press** — type where to go: a name, a path (its last segment is
///    matched) or `@handle`, matched loosely over the vault index;
///  * **↑** — the app bar's own back button, as before.
class BreadcrumbTitle extends StatelessWidget {
  final List<Crumb> crumbs;

  const BreadcrumbTitle({super.key, required this.crumbs});

  /// How many segments fit before the start folds into "…": a phone's app
  /// bar leaves room for the page and its parent, a tablet's for more.
  static int keepFor(double width) => width < 360 ? 2 : (width < 560 ? 3 : 4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
      return _build(context, keepFor(width), width);
    });
  }

  Widget _build(BuildContext context, int keep, double width) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final trimmed = trimCrumbs(crumbs, keep: keep);
    final parts = <Widget>[];

    void sep() => parts.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('›', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        ));

    if (trimmed.hidden.isNotEmpty) {
      parts.add(_Segment(
        label: '…',
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        onTap: () => _showHiddenSheet(context, trimmed.hidden),
      ));
    }
    for (var i = 0; i < trimmed.shown.length; i++) {
      final c = trimmed.shown[i];
      final last = i == trimmed.shown.length - 1;
      if (parts.isNotEmpty) sep();
      final segment = _Segment(
        label: c.label,
        style: last
            ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.bodyMedium?.copyWith(color: muted),
        onTap: () => showCrumbChildrenSheet(context, c, isCurrent: last),
      );
      // The page's own name takes whatever the path before it leaves; each
      // segment of that path keeps its natural width up to a share of the
      // bar, so a short parent name is never cut to "N…" for nothing.
      parts.add(last
          ? Flexible(child: segment)
          : ConstrainedBox(constraints: BoxConstraints(maxWidth: width * 0.34), child: segment));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: crumbs.isEmpty
          ? null
          : () => showGoToSheet(context, nexusId: crumbs.first.nexusId, initial: crumbs.map((c) => c.label).join(' / ')),
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }

  void _showHiddenSheet(BuildContext context, List<Crumb> hidden) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in hidden)
              ListTile(
                leading: Icon(c.moduleId == null ? Icons.workspaces_outlined : Icons.subdirectory_arrow_right),
                title: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _goFromSheet(sheet, c.location),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  const _Segment({required this.label, required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }
}

/// Pops the sheet [sheetContext] is in, then goes to [location]. The router
/// is taken first: the sheet's context is gone once it has closed.
void _goFromSheet(BuildContext sheetContext, String location) {
  final router = GoRouter.of(sheetContext);
  Navigator.of(sheetContext).pop();
  router.go(location);
}

/// What is inside [crumb]: child modules, and for a module its elements. An
/// element segment lists its siblings — the module's other elements.
Future<void> showCrumbChildrenSheet(BuildContext context, Crumb crumb, {required bool isCurrent}) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the Navibar, not under it: the shell's own navigator sits
    // above the bar, so a sheet opened on it would be cut off by it.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CrumbChildrenSheet(crumb: crumb, isCurrent: isCurrent),
  );
}

class _CrumbChildrenSheet extends ConsumerWidget {
  final Crumb crumb;
  final bool isCurrent;

  const _CrumbChildrenSheet({required this.crumb, required this.isCurrent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onElement = crumb.itemKey != null;
    final modules = onElement
        ? const AsyncValue<List<ModuleModel>>.data([])
        : ref.watch(moduleChildrenProvider(ModuleChildrenKey(crumb.nexusId, crumb.moduleId)));
    final index = crumb.moduleId == null ? null : ref.watch(nexusIndexProvider(crumb.nexusId));
    final elements = (index?.valueOrNull ?? const <IndexedItem>[])
        .where((it) => it.moduleId == crumb.moduleId && it.itemKind != 'module')
        .toList();
    final loading = modules.isLoading || (index?.isLoading ?? false);
    final childModules = modules.valueOrNull ?? const <ModuleModel>[];

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(crumb.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            ),
            if (!isCurrent)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.rowOpen),
                onTap: () => _goFromSheet(context, crumb.location),
              ),
            if (!isCurrent) const Divider(height: 1),
            if (loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (childModules.isEmpty && elements.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Text(
                  l10n.crumbEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in childModules)
                      ListTile(
                        leading: m.colorCode != null ? ColorDot(colorCode: m.colorCode, size: 20) : Icon(m.kindInfo.icon),
                        title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(m.kindInfo.label),
                        onTap: () => _goFromSheet(context, RecentView.locationFor(crumb.nexusId, m.id)),
                      ),
                    for (final it in elements)
                      ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: it.key == crumb.itemKey,
                        onTap: () => _goFromSheet(context, RecentView.locationFor(crumb.nexusId, it.moduleId, it.key)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Go to": type a name, a path or `@handle`; the vault index of [nexusId]
/// is matched loosely as the user types, and Enter takes the best match.
Future<void> showGoToSheet(BuildContext context, {required int nexusId, String initial = ''}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _GoToSheet(nexusId: nexusId, initial: initial),
  );
}

class _GoToSheet extends ConsumerStatefulWidget {
  final int nexusId;
  final String initial;

  const _GoToSheet({required this.nexusId, required this.initial});

  @override
  ConsumerState<_GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends ConsumerState<_GoToSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `@handle · module` — whichever of the two the row has.
  String? _hintOf(IndexedItem it) {
    final parts = [
      if (it.handle != null && it.handle!.isNotEmpty) '@${it.handle}',
      if (it.itemKind != 'module') it.moduleName,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _locationOf(IndexedItem it) =>
      RecentView.locationFor(widget.nexusId, it.moduleId, it.itemKind == 'module' ? null : it.key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final index = ref.watch(nexusIndexProvider(widget.nexusId)).valueOrNull ?? const <IndexedItem>[];
    final hits = SearchService.rankItems(index, _controller.text, loose: true).take(12).toList();

    return Padding(
      // Rides above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  labelText: l10n.goToTitle,
                  hintText: l10n.goToHint,
                  prefixIcon: const Icon(Icons.alt_route),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (hits.isNotEmpty) _goFromSheet(context, _locationOf(hits.first));
                },
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final it in hits)
                      ListTile(
                        dense: true,
                        leading: Icon(it.itemKind == 'module' ? Icons.folder_outlined : Icons.article_outlined, size: 20),
                        title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: _hintOf(it) == null
                            ? null
                            : Text(_hintOf(it)!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _goFromSheet(context, _locationOf(it)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/ddx_theme.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/recent_view_model.dart';
import '../../../data/models/viewer_model.dart';
import '../../../data/services/entity_location.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/color_dot.dart';

/// Shared bits of the per-kind views.

/// An empty-state line inside a view.
class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
    );
  }
}

/// A kind's empty page — the desktop's kindEmptyStateHtml (EXE
/// hub/kind-page.js), the component contract's empty state (APP
/// docs/redesign/COMPONENTS.md): the kind's icon in the module's colour, the
/// module's name, what the kind is for, a line about this page's state, and
/// ONE primary action. [EmptyHint] stays for the smaller empties inside a
/// view that already has content (no messages in a session, no routes).
class KindEmptyState extends StatelessWidget {
  final ModuleModel module;
  final String? note;
  final String? startLabel;
  final VoidCallback? onStart;
  const KindEmptyState({super.key, required this.module, this.note, this.startLabel, this.onStart});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final info = moduleKindInfo[module.kind]!;
    final code = module.colorCode;
    final color = code != null && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(code) ? hexToColor(code) : theme.colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(module.name, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(kindDesc(l, module.kind), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: context.ddx.textMuted)),
              ],
              if (onStart != null && startLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add, size: 18), label: Text(startLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A view's own toolbar: a title and up to a few actions (the desktop's
/// "toolbar ≤ 3 buttons" rule, APK-V3.md §5).
class ViewBar extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  const ViewBar({super.key, this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
        child: Row(
          children: [
            if (title != null) Text(title!, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            ...actions,
          ],
        ),
      );
}

/// Opens an entity's page.
Future<void> openKey(BuildContext context, WidgetRef ref, String key) async {
  final router = GoRouter.of(context);
  final db = await ref.read(databaseProvider.future);
  final loc = await EntityLocation.of(db, key);
  if (loc != null) router.push(loc);
}

/// Opens an element page of [moduleId].
void openElement(BuildContext context, int nexusId, int moduleId, String key) =>
    GoRouter.of(context).push(RecentView.locationFor(nexusId, moduleId, key));

/// Asks for one line of text; null when cancelled or empty.
Future<String?> askText(BuildContext context, String title, {String initial = '', String? label}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(d, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(MaterialLocalizations.of(d).cancelButtonLabel)),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(MaterialLocalizations.of(d).okButtonLabel)),
      ],
    ),
  );
  c.dispose();
  return r == null || r.isEmpty ? null : r;
}

/// A card-sized tile for grids and boards.
class TileCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final List<Widget> extra;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TileCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.extra = const [],
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
              ]),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
              ...extra,
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid that sizes to its content inside a page's scroll view.
class PageGrid extends StatelessWidget {
  final List<Widget> children;
  final double maxExtent;
  const PageGrid({super.key, required this.children, this.maxExtent = 200});

  @override
  Widget build(BuildContext context) => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 110,
        ),
        children: children,
      );
}

/// Picks one indexed entity of a Nexus: a searchable sheet over the same
/// index the Navigator and search read. [where] narrows the rows.
Future<IndexedItem?> pickEntity(BuildContext context, WidgetRef ref, int nexusId,
    {String? title, bool Function(IndexedItem it)? where}) async {
  final all = await ref.read(nexusIndexProvider(nexusId).future);
  final rows = [for (final it in all) if (where == null || where(it)) it];
  if (!context.mounted) return null;
  return showModalBottomSheet<IndexedItem>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _EntityPicker(rows: rows, title: title),
  );
}

class _EntityPicker extends StatefulWidget {
  final List<IndexedItem> rows;
  final String? title;
  const _EntityPicker({required this.rows, this.title});

  @override
  State<_EntityPicker> createState() => _EntityPickerState();
}

class _EntityPickerState extends State<_EntityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final it in widget.rows)
        if (q.isEmpty || it.name.toLowerCase().contains(q) || it.moduleName.toLowerCase().contains(q)) it,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(widget.title!, style: Theme.of(context).textTheme.titleMedium),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.labelSearch, isDense: true),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (c, i) {
                  final it = shown[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(moduleKindInfo[ModuleKind.fromId(it.moduleKind)]?.icon ?? Icons.label_outline, size: 20),
                    title: Text(it.name.isEmpty ? '—' : it.name),
                    subtitle: it.itemKind == 'module' ? null : Text(it.moduleName),
                    onTap: () => Navigator.pop(context, it),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

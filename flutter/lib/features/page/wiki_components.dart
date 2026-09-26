import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/models/viewer_model.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/markdown_view.dart';
import 'block_options.dart';
import 'component_registry.dart';
import 'links.dart';
import 'module_page.dart';
import 'page_providers.dart';

/// The wiki components on the phone (Procress 14, APP docs/TEMPLATES.md §7;
/// EXE renderer/page/components/wiki.js, wiki-more.js): link bars and cards,
/// the hatnote, See also, a navbox, a page's children, References, and the
/// two containers — tabs and a toggle — that hold blocks of their own the
/// way columns do (parent_id + config.col).
final List<ComponentDef> wikiComponents = [
  ComponentDef(id: 'core.linkbar', kind: null, label: (l) => l.pcLinkbar, build: (c, x) => _LinkBar(ctx: x)),
  ComponentDef(id: 'core.linkcard', kind: null, label: (l) => l.pcLinkcard, build: (c, x) => _LinkCards(ctx: x)),
  ComponentDef(id: 'core.hatnote', kind: null, once: true, label: (l) => l.pcHatnote, build: (c, x) => _Hatnote(ctx: x)),
  ComponentDef(id: 'core.seealso', kind: null, once: true, label: (l) => l.pcSeeAlso, build: (c, x) => _SeeAlso(ctx: x)),
  ComponentDef(id: 'core.references', kind: null, once: true, label: (l) => l.pcReferences, build: (c, x) => _References(ctx: x)),
  ComponentDef(id: 'core.tabs', kind: null, label: (l) => l.pcTabs, build: (c, x) => _Tabs(ctx: x)),
  ComponentDef(id: 'core.toggle', kind: null, label: (l) => l.pcToggle, build: (c, x) => _Toggle(ctx: x)),
  ComponentDef(id: 'core.navbox', kind: null, label: (l) => l.pcNavbox, build: (c, x) => _Navbox(ctx: x)),
  ComponentDef(id: 'core.children', kind: null, label: (l) => l.pcChildren, build: (c, x) => _Children(ctx: x)),
];

/// Each wiki component's icon in the add sheet.
const wikiIcons = {
  'core.linkbar': Icons.linear_scale,
  'core.linkcard': Icons.dashboard_outlined,
  'core.hatnote': Icons.short_text,
  'core.seealso': Icons.subdirectory_arrow_right,
  'core.navbox': Icons.view_list_outlined,
  'core.children': Icons.account_tree_outlined,
  'core.references': Icons.format_list_numbered,
  'core.tabs': Icons.tab_outlined,
  'core.toggle': Icons.unfold_more,
};

/// The containers: a block of these holds blocks, in slots (config.col).
const containerComponents = {'core.tabs', 'core.toggle'};

/// The tab names a tabs block shows — at most 8, and two when none are set
/// (EXE pcTabNames).
List<String> tabNames(AppLocalizations l10n, Object? v) {
  final names = [for (final s in (v is List ? v : const [])) '${s ?? ''}'.trim()].where((s) => s.isNotEmpty).take(8).toList();
  return names.isNotEmpty ? names : ['${l10n.pcTab} 1', '${l10n.pcTab} 2'];
}

/// The links of a block's `links` option and the Nexus index they resolve
/// through (null while it loads).
(List<PageLink>, List<IndexedItem>?) _links(WidgetRef ref, ComponentCtx ctx, [String key = 'links']) =>
    (linksFrom(optValue(ctx.block, key)), ref.watch(nexusIndexProvider(ctx.nexusId)).valueOrNull);

Widget _emptyLinks(BuildContext context, WidgetRef ref, ComponentCtx ctx) {
  final l10n = AppLocalizations.of(context)!;
  final arranging = ref.watch(arrangeModeProvider(ctx.key));
  return Text(arranging ? l10n.pbLinksEmptyArrange : l10n.pbLinksEmpty, style: TextStyle(color: context.ddx.textMuted));
}

/// Where the link goes, when it leaves the app — the domain always shows.
Widget? _ext(ResolvedLink r, Color c) =>
    r.kind == LinkKind.url
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Text(' ${r.host} ', style: TextStyle(fontSize: 12, color: c)),
            Icon(Icons.north_east, size: 12, color: c),
          ])
        : null;

/// "Leaves the app" — an icon, since the ↗ glyph is missing from the
/// bundled fonts and prints as a box.
InlineSpan _outSpan(Color c) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(padding: const EdgeInsets.only(left: 3), child: Icon(Icons.north_east, size: 14, color: c)),
    );

bool _here(ResolvedLink r, ComponentCtx ctx) =>
    (r.kind == LinkKind.module && r.moduleId == ctx.page.module.id && ctx.itemKey == null) ||
    (r.kind == LinkKind.item && r.key != null && r.key == ctx.itemKey);

// ── link bar ────────────────────────────────────────────────────────────
class _LinkBar extends ConsumerWidget {
  final ComponentCtx ctx;
  const _LinkBar({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (links, index) = _links(ref, ctx);
    if (links.isEmpty) return _emptyLinks(context, ref, ctx);
    final bar = '${optValue(ctx.block, 'bar')}';
    final scheme = Theme.of(context).colorScheme;
    final items = [
      for (final l in links)
        () {
          final r = resolveLink(l, index);
          final on = _here(r, ctx);
          final label = Text.rich(TextSpan(children: [
            TextSpan(text: linkLabel(l, r)),
            if (r.kind == LinkKind.url) _outSpan(scheme.onSurfaceVariant),
          ]));
          void go() => followLink(context, ref, l, r, ctx.nexusId);
          final dim = r.dangling ? .55 : 1.0;
          return Opacity(
            opacity: dim,
            child: switch (bar) {
              'buttons' => on ? FilledButton(onPressed: go, child: label) : OutlinedButton(onPressed: go, child: label),
              'tabs' || 'underline' => InkWell(
                  onTap: go,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: on ? scheme.primary : Colors.transparent, width: 2))),
                    child: DefaultTextStyle.merge(style: TextStyle(color: on ? scheme.primary : null, fontWeight: on ? FontWeight.w600 : null), child: label),
                  ),
                ),
              _ => ActionChip(label: label, onPressed: go, backgroundColor: on ? scheme.primaryContainer : null),
            },
          );
        }(),
    ];
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [for (final w in items) Padding(padding: const EdgeInsets.only(right: 6), child: w)]),
    );
    final framed = bar == 'tabs' || bar == 'underline'
        ? DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))), child: row)
        : row;
    return '${optValue(ctx.block, 'align')}' == 'center' ? Center(child: framed) : framed;
  }
}

// ── link cards ──────────────────────────────────────────────────────────
class _LinkCards extends ConsumerWidget {
  final ComponentCtx ctx;
  const _LinkCards({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (links, index) = _links(ref, ctx);
    if (links.isEmpty) return _emptyLinks(context, ref, ctx);
    final layout = '${optValue(ctx.block, 'layout')}';
    final muted = context.ddx.textMuted;
    return LayoutBuilder(builder: (context, box) {
      final want = int.tryParse('${optValue(ctx.block, 'cols')}') ?? 2;
      final cols = box.maxWidth < 360 ? 1 : (box.maxWidth < 560 ? want.clamp(1, 2) : want);
      final w = (box.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in links)
          SizedBox(
            width: layout == 'button' ? null : w,
            child: () {
              final r = resolveLink(l, index);
              void go() => followLink(context, ref, l, r, ctx.nexusId);
              final title = linkLabel(l, r);
              final sub = r.kind == LinkKind.url
                  ? r.host!
                  : r.kind == LinkKind.item
                      ? (index?.where((e) => e.key == r.key).firstOrNull?.moduleName ?? '')
                      : '';
              if (layout == 'button') return FilledButton.tonal(onPressed: go, child: Text(title));
              return Opacity(
                opacity: r.dangling ? .55 : 1,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: go,
                    child: Padding(
                      padding: EdgeInsets.all(layout == 'compact' ? 10 : 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (sub.isNotEmpty && layout != 'compact')
                          Text.rich(TextSpan(children: [TextSpan(text: sub), if (r.kind == LinkKind.url) _outSpan(muted)]),
                              style: TextStyle(fontSize: 12, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ),
                ),
              );
            }(),
          ),
      ]);
    });
  }
}

// ── hatnote ─────────────────────────────────────────────────────────────
class _Hatnote extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Hatnote({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final (links, index) = _links(ref, ctx);
    final muted = context.ddx.textMuted;
    final style = TextStyle(fontStyle: FontStyle.italic, color: muted);
    // a page written before the link model keeps its free line
    if (links.isEmpty) {
      final text = ctx.block.content ?? '';
      return text.isEmpty ? Text(l10n.pcHatnotePh, style: style) : MarkdownView(text: text, nexusId: ctx.nexusId, style: style);
    }
    final kind = '${optValue(ctx.block, 'kind')}';
    final lead = switch (kind) { 'about' => l10n.pcHatAbout, 'distinguish' => l10n.pcHatDistinguish, _ => l10n.pcHatMain };
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[TextSpan(text: '$lead ')];
    for (var i = 0; i < links.length; i++) {
      final r = resolveLink(links[i], index);
      if (i > 0) spans.add(TextSpan(text: i == links.length - 1 ? ' ${l10n.pcHatAnd} ' : ', '));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => followLink(context, ref, links[i], r, ctx.nexusId),
          child: Text(linkLabel(links[i], r),
              style: style.copyWith(color: scheme.primary.withValues(alpha: r.dangling ? .55 : 1), decoration: TextDecoration.underline)),
        ),
      ));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

// ── see also ────────────────────────────────────────────────────────────
class _SeeAlso extends ConsumerWidget {
  final ComponentCtx ctx;
  const _SeeAlso({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final (links, index) = _links(ref, ctx);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.pcSeeAlso, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      if (links.isEmpty) Text(l10n.pcSeeAlsoEmpty, style: TextStyle(color: context.ddx.textMuted)),
      for (final l in links)
        () {
          final r = resolveLink(l, index);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(r.kind == LinkKind.url ? Icons.public : Icons.subdirectory_arrow_right, size: 18),
            title: Text(linkLabel(l, r), style: TextStyle(color: Theme.of(context).colorScheme.primary.withValues(alpha: r.dangling ? .55 : 1))),
            trailing: _ext(r, context.ddx.textMuted),
            onTap: () => followLink(context, ref, l, r, ctx.nexusId),
          );
        }(),
    ]);
  }
}

// ── references ──────────────────────────────────────────────────────────
class _References extends StatelessWidget {
  final ComponentCtx ctx;
  const _References({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notes = pageFootnotes(ctx.page);
    final base = Theme.of(context).textTheme.bodySmall!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.pcReferences, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      if (notes.order.isEmpty) Text(l10n.pcReferencesEmpty, style: TextStyle(color: context.ddx.textMuted)),
      for (final id in notes.order)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 26, child: Text('${notes.number(id)}.', style: base)),
            Expanded(
              child: MarkdownView(
                  text: notes.notes[id] ?? l10n.pbFootnoteMissing, nexusId: ctx.nexusId, style: base.copyWith(fontStyle: notes.notes[id] == null ? FontStyle.italic : null)),
            ),
          ]),
        ),
    ]);
  }
}

/// A page's footnotes: every text block, in page order.
Footnotes pageFootnotes(PageData page) => Footnotes.of(
      [for (final b in page.blocks) if (b.type == 'text' && (b.content ?? '').isNotEmpty) b.content!],
      hideDefs: page.blocks.any((b) => b.component == 'core.references'),
    );

// ── tabs and toggle: containers ─────────────────────────────────────────
List<Widget> _slot(ComponentCtx ctx, int col) => [
      // the container already sits at the page's inset
      for (final b in ctx.page.childrenOf(ctx.block, col)) BlockView(page: ctx.page, block: b, itemKey: ctx.itemKey, wide: ctx.wide, inset: 0),
    ];

class _Tabs extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const _Tabs({required this.ctx});

  @override
  ConsumerState<_Tabs> createState() => _TabsState();
}

class _TabsState extends ConsumerState<_Tabs> {
  int? _on;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctx = widget.ctx;
    final names = tabNames(l10n, optValue(ctx.block, 'tabs'));
    final start = ((optValue(ctx.block, 'start') as num?)?.toInt() ?? 1) - 1;
    final on = (_on ?? start).clamp(0, names.length - 1);
    final look = '${optValue(ctx.block, 'look')}';
    final scheme = Theme.of(context).colorScheme;
    final strip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < names.length; i++)
          Padding(
            padding: EdgeInsets.only(right: look == 'line' ? 0 : 6),
            child: Semantics(
              selected: i == on,
              button: true,
              child: switch (look) {
                'pills' => ChoiceChip(label: Text(names[i]), selected: i == on, onSelected: (_) => setState(() => _on = i)),
                'boxed' => InkWell(
                    onTap: () => setState(() => _on = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: i == on ? scheme.surfaceContainerHighest : null,
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                      child: Text(names[i], style: TextStyle(fontWeight: i == on ? FontWeight.w600 : null)),
                    ),
                  ),
                _ => InkWell(
                    onTap: () => setState(() => _on = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == on ? scheme.primary : Colors.transparent, width: 2))),
                      child: Text(names[i], style: TextStyle(color: i == on ? scheme.primary : null, fontWeight: i == on ? FontWeight.w600 : null)),
                    ),
                  ),
              },
            ),
          ),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      look == 'line'
          ? DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))), child: strip)
          : strip,
      const SizedBox(height: 6),
      ..._slot(ctx, on),
    ]);
  }
}

class _Toggle extends StatefulWidget {
  final ComponentCtx ctx;
  const _Toggle({required this.ctx});

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctx = widget.ctx;
    final title = '${optValue(ctx.block, 'title') ?? ''}'.trim();
    final open = _open ?? optValue(ctx.block, 'start') == 'open';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              AnimatedRotation(turns: open ? .25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.chevron_right)),
              const SizedBox(width: 4),
              Expanded(child: Text(title.isEmpty ? l10n.pcToggle : title, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
      if (open) ..._slot(ctx, 0),
    ]);
  }
}

// ── navbox ──────────────────────────────────────────────────────────────
class _Navbox extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const _Navbox({required this.ctx});

  @override
  ConsumerState<_Navbox> createState() => _NavboxState();
}

class _NavboxState extends ConsumerState<_Navbox> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctx = widget.ctx;
    final (links, index) = _links(ref, ctx);
    final source = optValue(ctx.block, 'source') as int?;
    final title = '${optValue(ctx.block, 'title') ?? ''}'.trim();
    final open = _open ?? optValue(ctx.block, 'start') != 'closed';
    // the chosen module's elements first, then each link group
    final groups = <String, List<Widget>>{};
    Widget chip(String label, VoidCallback onTap, {bool dim = false}) => Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: ActionChip(visualDensity: VisualDensity.compact, label: Text(label), onPressed: onTap, side: dim ? BorderSide.none : null),
        );
    if (source != null && index != null) {
      final src = index.where((e) => e.key == 'module_$source').firstOrNull;
      final items = index.where((e) => e.moduleId == source && e.itemKind != 'module').toList()..sort((a, b) => a.name.compareTo(b.name));
      if (src != null) {
        groups[src.name] = [
          for (final e in items)
            chip(e.name, () => GoRouter.of(context).push(RecentView.locationFor(ctx.nexusId, e.moduleId, e.key))),
        ];
      }
    }
    for (final l in links) {
      final r = resolveLink(l, index);
      (groups[l.group] ??= []).add(chip(linkLabel(l, r), () => followLink(context, ref, l, r, ctx.nexusId), dim: r.dangling));
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !open),
          child: Container(
            color: scheme.surfaceContainerHighest.withValues(alpha: .6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Text(title.isEmpty ? l10n.pcNavbox : title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.all(10),
            child: groups.isEmpty
                ? Text(l10n.pbLinksEmpty, style: TextStyle(color: context.ddx.textMuted))
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final g in groups.entries) ...[
                      if (g.key.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(g.key, style: Theme.of(context).textTheme.labelMedium)),
                      Wrap(children: g.value),
                    ],
                  ]),
          ),
      ]),
    );
  }
}

// ── children ────────────────────────────────────────────────────────────
class _Children extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Children({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final depth = ((optValue(ctx.block, 'depth') as num?)?.toInt() ?? 1).clamp(1, 3);
    final layout = '${optValue(ctx.block, 'layout')}';
    final byName = optValue(ctx.block, 'sort') == 'name';
    final m = ctx.page.module;

    List<Widget> level(int? parentId, int d) {
      final kids = [...?ref.watch(moduleChildrenProvider(ModuleChildrenKey(m.nexusRef, parentId))).valueOrNull];
      if (byName) kids.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return [
        for (final k in kids) ...[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: layout == 'tree' ? 16.0 * (d - 1) : 0),
            leading: Icon(moduleKindInfo[k.kind]?.icon ?? Icons.folder_outlined, size: 20),
            title: Text(k.name),
            onTap: () => GoRouter.of(context).push(RecentView.locationFor(m.nexusRef, k.id)),
          ),
          if (d < depth) ...level(k.id, d + 1),
        ],
      ];
    }

    final rows = level(m.id, 1);
    if (rows.isEmpty) return Text(l10n.pcChildrenNone, style: TextStyle(color: context.ddx.textMuted));
    if (layout != 'cards') return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    final kids = ref.watch(moduleChildrenProvider(ModuleChildrenKey(m.nexusRef, m.id))).valueOrNull ?? const <ModuleModel>[];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final k in kids)
        SizedBox(
          width: 160,
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => GoRouter.of(context).push(RecentView.locationFor(m.nexusRef, k.id)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(moduleKindInfo[k.kind]?.icon ?? Icons.folder_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(k.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

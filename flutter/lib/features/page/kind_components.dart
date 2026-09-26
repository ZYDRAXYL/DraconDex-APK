import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/dao/diviner_dao.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/services/wiki_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/markdown_view.dart';
import 'block_options.dart';
import 'block_style.dart';
import 'component_registry.dart';
import 'core_components.dart';
import 'links.dart';
import 'page_providers.dart';
import 'views/view_common.dart';

/// The page components a template names that read their module's data —
/// the phone's port of EXE renderer/page/components/core.js, kinds.js and
/// kinds-more.js (APP docs/TEMPLATES.md §2). Each reads the page's own
/// module, or the one a borrowed block names, straight from the vault.
final List<ComponentDef> dataComponents = [
  _def('core.infobox', null, (l) => l.pcInfobox, _infobox, once: true),
  ComponentDef(id: 'core.callout', kind: null, label: (l) => l.pcCallout, build: (c, x) => _Callout(ctx: x)),
  _def('core.stats', null, (l) => l.pcStats, _stats),
  ComponentDef(id: 'core.toc', kind: null, once: true, label: (l) => l.pcToc, build: (c, x) => _Toc(ctx: x)),
  _def('classifier.spotlight', ModuleKind.classifier, (l) => l.pcSpotlight, _spotlight),
  _def('classifier.roster', ModuleKind.classifier, (l) => l.pcRoster, _roster),
  _def('classifier.breakdown', ModuleKind.classifier, (l) => l.pcBreakdown, _breakdown),
  _def('chronicler.eras', ModuleKind.chronicler, (l) => l.pcEras, _eras),
  _def('chronicler.upcoming', ModuleKind.chronicler, (l) => l.pcUpcoming, _upcoming),
  _def('locator.pinlist', ModuleKind.locator, (l) => l.pcPinlist, _pinlist),
  _def('author.progress', ModuleKind.author, (l) => l.pcProgress, _progress),
  _def('author.chapters', ModuleKind.author, (l) => l.pcChapters, _chapters),
  _def('narrator.endings', ModuleKind.narrator, (l) => l.pcEndings, _endings),
  _def('narrator.variables', ModuleKind.narrator, (l) => l.pcVariables, _variables),
  _def('exhibitor.focus', ModuleKind.exhibitor, (l) => l.pcFocus, _focus),
  _def('exhibitor.legend', ModuleKind.exhibitor, (l) => l.pcLegend, _legend),
  _def('wanderer.journey', ModuleKind.wanderer, (l) => l.pcJourney, _journey, borrow: false),
  _def('designer.strip', ModuleKind.designer, (l) => l.pcStrip, _strip),
  _def('sketcher.featured', ModuleKind.sketcher, (l) => l.pcFeatured, _featured),
  _def('manager.dashboard', ModuleKind.manager, (l) => l.pcDashboard, _dashboard, once: true, borrow: false),
  _def('manager.recent', ModuleKind.manager, (l) => l.pcRecent, _recent, once: true, borrow: false),
  ComponentDef(id: 'diviner.quickroll', kind: ModuleKind.diviner, borrow: true, label: (l) => l.pcQuickroll, build: (c, x) => _QuickRoll(ctx: x)),
  _def('scribe.pinned', ModuleKind.scribe, (l) => l.pcPinned, _pinned),
  _def('drafter.tasks', ModuleKind.drafter, (l) => l.pcTasks, _tasks),
];

/// A component that reads, then draws: [load] runs against the vault, and
/// [draw] gets what it returned.
typedef _Load = Future<Object?> Function(Database db, ComponentCtx ctx);
typedef _Draw = Widget Function(BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? data);

ComponentDef _def(String id, ModuleKind? kind, String Function(AppLocalizations) label, (_Load, _Draw) spec,
        {bool once = false, bool borrow = true}) =>
    ComponentDef(
      id: id,
      kind: kind,
      once: once,
      borrow: kind != null && borrow,
      label: label,
      build: (c, x) => _Filled(ctx: x, load: spec.$1, draw: spec.$2),
    );

class _FillKey {
  final String id;
  final int source;
  final String? item;
  final int page; // the PageData it drew with: a reload reads again
  final String config;
  final _Load load;
  final ComponentCtx ctx;
  _FillKey(this.ctx, this.load)
      : id = ctx.block.component ?? '',
        source = ctx.source.id,
        item = ctx.itemKey,
        page = identityHashCode(ctx.page),
        config = jsonEncode(ctx.block.config);

  @override
  bool operator ==(Object o) => o is _FillKey && o.id == id && o.source == source && o.item == item && o.page == page && o.config == config;

  @override
  int get hashCode => Object.hash(id, source, item, page, config);
}

final _fillProvider = FutureProvider.autoDispose.family<Object?, _FillKey>((ref, k) async {
  final db = await ref.watch(databaseProvider.future);
  return k.load(db, k.ctx);
});

class _Filled extends ConsumerWidget {
  final ComponentCtx ctx;
  final _Load load;
  final _Draw draw;
  const _Filled({required this.ctx, required this.load, required this.draw});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ref.watch(_fillProvider(_FillKey(ctx, load))).when(
          data: (d) => draw(context, ref, ctx, d),
          loading: () => const SizedBox(height: 48),
          // a read that fails leaves a quiet line, not a broken page
          error: (e, _) => _empty(context, l10n.pcLoadFailed),
        );
  }
}

Widget _empty(BuildContext context, String text) => Text(text, style: TextStyle(color: context.ddx.textMuted));

Widget _head(BuildContext context, String text) =>
    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: Theme.of(context).textTheme.titleSmall));

Color? _hex(Object? c) {
  final s = '${c ?? ''}'.replaceFirst('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return s.length == 6 && v != null ? Color(v) : null;
}

Widget _dot(Color? c, BuildContext context) => Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: c ?? Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
    );

Widget _row(BuildContext context, {Color? dot, Widget? lead, required String main, String? side, String? sub, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          lead ?? _dot(dot, context),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(main, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (sub != null && sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
            ]),
          ),
          if (side != null && side.isNotEmpty) Text(side, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
        ]),
      ),
    );

/// Labelled count bars (breakdown, eras, progress, legend) — EXE pcBarsHtml.
Widget _bars(BuildContext context, List<(String, int, Color?)> rows) {
  final top = max(1, rows.fold<int>(0, (m, r) => max(m, r.$2)));
  final scheme = Theme.of(context).colorScheme;
  return Column(children: [
    for (final (label, n, color) in rows)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: n / top,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: color ?? scheme.primary,
              ),
            ),
          ),
          SizedBox(width: 44, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
        ]),
      ),
  ]);
}

String _pad(Object? n) => '${n ?? 0}'.padLeft(2, '0');
String _date(Map<String, Object?> r, [String p = 's_']) =>
    r['${p}years'] == null ? '' : '${r['${p}years']}.${_pad(r['${p}month'])}.${_pad(r['${p}day'])}';

void _openKey(BuildContext context, WidgetRef ref, String key) => openKey(context, ref, key);
void _openModule(BuildContext context, ComponentCtx ctx, int id) => GoRouter.of(context).push(RecentView.locationFor(ctx.nexusId, id));

/// A Classifier field by its key (a template's config.field) — the key
/// rides in the field's options — or, for an older field, its name.
Map<String, Object?>? _findField(List<Map<String, Object?>> templates, String key) {
  String? keyOf(Map<String, Object?> t) {
    try {
      final o = jsonDecode('${t['options'] ?? '{}'}');
      return o is Map ? o['key'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  return templates.where((t) => keyOf(t) == key).firstOrNull ?? templates.where((t) => t['description'] == key).firstOrNull;
}

int? _objectId(String? itemKey) => RegExp(r'^cobj_(\d+)$').firstMatch(itemKey ?? '') == null ? null : int.parse(itemKey!.substring(5));

Future<List<Map<String, Object?>>> _templates(Database db, int moduleId) => db.rawQuery(
    'SELECT id, description, attribute_type, options FROM classifier_template WHERE module_ref=? AND object_ref IS NULL ORDER BY display_order, id',
    [moduleId]);

Future<Map<int, String?>> _attrs(Database db, int objectId) async => {
      for (final r in await db.rawQuery('SELECT template_ref, attribute_value FROM classifier_attribute WHERE object_ref=?', [objectId]))
        r['template_ref'] as int: r['attribute_value'] as String?,
    };

// ── core ────────────────────────────────────────────────────────────────
final _infobox = (
  (Database db, ComponentCtx ctx) async {
    final oid = _objectId(ctx.itemKey);
    final rows = <(String, String)>[];
    if (oid != null) {
      final templates = await _templates(db, ctx.page.module.id);
      final attrs = await _attrs(db, oid);
      final want = optValue(ctx.block, 'fields');
      final fields = want is List && want.isNotEmpty
          ? [for (final k in want) ?_findField(templates, '$k')]
          : templates.where((t) => t['attribute_type'] != 'relation').toList();
      for (final t in fields) {
        rows.add(('${t['description']}', attrs[t['id'] as int] ?? ''));
      }
    } else {
      for (final p in ctx.page.props) {
        rows.add((p.propName ?? '', p.content ?? ''));
      }
    }
    final title = ctx.itemKey != null ? (await EntityKinds.nameOf(db, ctx.itemKey!) ?? '') : ctx.source.name;
    return (title, rows);
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final (title, rows) = d as (String, List<(String, String)>);
    final l10n = AppLocalizations.of(context)!;
    final stacked = optValue(ctx.block, 'layout') == 'stacked';
    final muted = context.ddx.textMuted;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
          if (rows.isEmpty) _empty(context, l10n.pcInfoboxEmpty),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: stacked
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                      Text(v.isEmpty ? '—' : v),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 120, child: Text(k, style: TextStyle(color: muted, fontWeight: FontWeight.w600))),
                      Expanded(child: Text(v.isEmpty ? '—' : v)),
                    ]),
            ),
        ]),
      ),
    );
  },
);

/// Callout: a note in a tone, written right on the page (block.content).
class _Callout extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Callout({required this.ctx});

  static const tones = {
    'note': (Icons.info_outline, 'accent'),
    'tip': (Icons.lightbulb_outline, 'green'),
    'warning': (Icons.warning_amber_outlined, 'amber'),
    'quote': (Icons.format_quote, 'slate'),
    'secret': (Icons.visibility_off_outlined, 'violet'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tone = tones['${optValue(ctx.block, 'tone')}'] ?? tones['note']!;
    final acc = accentColor(context, tone.$2);
    final text = ctx.block.content ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(acc.withValues(alpha: .12), Theme.of(context).scaffoldBackgroundColor),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: acc, width: 3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(tone.$1, color: acc, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final next = await editTextSheet(context, title: l10n.pcCallout, initial: text, nexusId: ctx.nexusId);
              if (next == null || next == text) return;
              final dao = await ref.read(pageBlockDaoProvider.future);
              await dao.update(ctx.block.id, content: next, clear: {if (next.isEmpty) 'content'});
              ref.invalidate(pageProvider(ctx.key));
            },
            child: text.isEmpty
                ? Text(l10n.pcCalloutPh, style: TextStyle(color: context.ddx.textMuted))
                : MarkdownView(text: text, nexusId: ctx.nexusId),
          ),
        ),
      ]),
    );
  }
}

final _stats = (
  (Database db, ComponentCtx ctx) async {
    final tiles = <(String, String)>[];
    final oid = _objectId(ctx.itemKey);
    final want = ctx.block.config['tiles'];
    if (oid != null && want is List && want.isNotEmpty) {
      final templates = await _templates(db, ctx.page.module.id);
      final attrs = await _attrs(db, oid);
      for (final t in want.take(6)) {
        if (t is! Map) continue;
        final f = _findField(templates, '${t['field']}');
        if (f != null) tiles.add(('${t['label'] ?? f['description']}', attrs[f['id'] as int] ?? '—'));
      }
      return tiles;
    }
    final src = ctx.source.id;
    final items = (await db.rawQuery('''
      SELECT (SELECT COUNT(*) FROM classifier_object WHERE module_ref=?1)
           + (SELECT COUNT(*) FROM book_chapter WHERE module_ref=?1)
           + (SELECT COUNT(*) FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id WHERE tl.module_ref=?1)
           + (SELECT COUNT(*) FROM chat_session WHERE module_ref=?1) AS n''', [src])).first['n'];
    tiles.add(('items', '$items'));
    final kids = (await db.rawQuery('SELECT COUNT(*) AS n FROM module WHERE parent_id=?', [src])).first['n'] as int;
    if (kids > 0) tiles.add(('modules', '$kids'));
    tiles.add(('backlinks', '${(await WikiService.backlinks(db, 'module_$src')).length}'));
    return tiles;
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = d as List<(String, String)>;
    if (tiles.isEmpty) return _empty(context, l10n.pcStatsEmpty);
    String name(String k) => switch (k) { 'items' => l10n.pcStatItems, 'modules' => l10n.pcStatModules, 'backlinks' => l10n.backlinks, _ => k };
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (k, v) in tiles)
        Container(
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(name(k), style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
          ]),
        ),
    ]);
  },
);

/// Contents: the page's own headings; a tap scrolls to one.
class _Toc extends StatelessWidget {
  final ComponentCtx ctx;
  const _Toc({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hs = ctx.page.blocks.where((b) => b.type == 'heading' && (b.content ?? '').trim().isNotEmpty).toList();
    if (hs.isEmpty) return _empty(context, l10n.pcTocEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcToc),
      for (final b in hs)
        InkWell(
          onTap: () {
            final a = BlockStyle.of(b.config).anchor;
            PageAnchors.scrollTo(a.isNotEmpty ? a : 'b${b.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(b.content!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ),
    ]);
  }
}

// ── classifier ──────────────────────────────────────────────────────────
Future<List<Map<String, Object?>>> _objects(Database db, int moduleId) => db.rawQuery(
    'SELECT o.id, o.name, c.color_code FROM classifier_object o LEFT JOIN use_color c ON o.color=c.id WHERE o.module_ref=? ORDER BY o.display_order, o.id',
    [moduleId]);

Widget _avatar(BuildContext context, Map<String, Object?> o, double size) => CircleAvatar(
      radius: size / 2,
      backgroundColor: _hex(o['color_code']) ?? Theme.of(context).colorScheme.primaryContainer,
      child: Text('${o['name'] ?? '?'}'.characters.firstOrNull ?? '?', style: TextStyle(fontSize: size * .42, color: Colors.white)),
    );

final _spotlight = (
  (Database db, ComponentCtx ctx) async {
    final objs = await _objects(db, ctx.source.id);
    if (objs.isEmpty) return null;
    // a different one each day
    final o = objs[(DateTime.now().millisecondsSinceEpoch ~/ 86400000) % objs.length];
    final templates = await _templates(db, ctx.source.id);
    final attrs = await _attrs(db, o['id'] as int);
    final facts = [
      for (final t in templates)
        if (t['attribute_type'] != 'relation' && (attrs[t['id'] as int] ?? '').isNotEmpty) ('${t['description']}', attrs[t['id'] as int]!),
    ].take(3).toList();
    return (o, facts);
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    if (d == null) return _empty(context, l10n.pcNoElements);
    final (o, facts) = d as (Map<String, Object?>, List<(String, String)>);
    return InkWell(
      onTap: () => _openKey(context, ref, 'cobj_${o['id']}'),
      child: Row(children: [
        _avatar(context, o, 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.pcSpotlight.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: .8, color: context.ddx.textMuted)),
            Text('${o['name']}', style: Theme.of(context).textTheme.titleLarge),
            for (final (k, v) in facts) Text('$k  $v', style: TextStyle(fontSize: 13, color: context.ddx.textMuted)),
          ]),
        ),
      ]),
    );
  },
);

final _roster = (
  (Database db, ComponentCtx ctx) async => _objects(db, ctx.source.id),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final objs = d as List<Map<String, Object?>>;
    if (objs.isEmpty) return _empty(context, AppLocalizations.of(context)!.pcNoElements);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final o in objs.take(60))
        InkWell(
          onTap: () => _openKey(context, ref, 'cobj_${o['id']}'),
          child: SizedBox(
            width: 76,
            child: Column(children: [
              _avatar(context, o, 52),
              const SizedBox(height: 4),
              Text('${o['name']}', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
    ]);
  },
);

final _breakdown = (
  (Database db, ComponentCtx ctx) async {
    final templates = await _templates(db, ctx.source.id);
    final field = optValue(ctx.block, 'field');
    final tp = (field is String && field.isNotEmpty ? _findField(templates, field) : null) ??
        templates.where((t) => t['attribute_type'] == 'select').firstOrNull ??
        templates.where((t) => t['attribute_type'] != 'relation').firstOrNull;
    if (tp == null) return null;
    final objs = await _objects(db, ctx.source.id);
    if (objs.isEmpty) return null;
    final counts = <String, int>{};
    for (final o in objs) {
      final v = ((await _attrs(db, o['id'] as int))[tp['id'] as int] ?? '').trim();
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ('${tp['description']}', rows.take(12).map((e) => (e.key, e.value)).toList());
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    if (d == null) return _empty(context, l10n.pcBreakdownEmpty);
    final (name, rows) = d as (String, List<(String, int)>);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, name),
      _bars(context, [for (final (k, n) in rows) (k.isEmpty ? l10n.pcNoValue : k, n, null)]),
    ]);
  },
);

// ── chronicler ──────────────────────────────────────────────────────────
Future<List<Map<String, Object?>>> _events(Database db, int moduleId) => db.rawQuery('''
  SELECT te.id, te.event_name, c.color_code, s.day s_day, s.month s_month, s.years s_years
  FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id
  JOIN timeline_date s ON te.start_at=s.id LEFT JOIN use_color c ON te.color=c.id
  WHERE tl.module_ref=? ORDER BY s.years, s.month, s.day, te.id''', [moduleId]);

final _eras = (
  (Database db, ComponentCtx ctx) async => _events(db, ctx.source.id),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final evs = d as List<Map<String, Object?>>;
    if (evs.isEmpty) return _empty(context, l10n.noEventsYet);
    // up to six spans of the story, each with what happens first in it
    final first = evs.first['s_years'] as int, last = evs.last['s_years'] as int;
    final n = min(6, max(1, last - first + 1));
    final span = max(1, ((last - first + 1) / n).ceil());
    final eras = List.generate(n, (i) => (first + i * span, min(last, first + (i + 1) * span - 1), <Map<String, Object?>>[]));
    for (final e in evs) {
      eras[min(n - 1, ((e['s_years'] as int) - first) ~/ span)].$3.add(e);
    }
    return Column(children: [
      for (final (from, to, list) in eras)
        _row(context,
            main: list.isEmpty ? '—' : '${list.first['event_name'] ?? ''}${list.length > 1 ? '  +${list.length - 1}' : ''}',
            side: from == to ? '$from' : '$from–$to',
            dot: list.isEmpty ? null : _hex(list.first['color_code']),
            onTap: list.isEmpty ? null : () => _openKey(context, ref, 'tlev_${list.first['id']}')),
    ]);
  },
);

final _upcoming = (
  (Database db, ComponentCtx ctx) async {
    final from = optValue(ctx.block, 'from');
    final evs = await _events(db, ctx.source.id);
    return (from is num ? evs.where((e) => (e['s_years'] as int) >= from) : evs).take(5).toList();
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final list = d as List<Map<String, Object?>>;
    if (list.isEmpty) return _empty(context, l10n.noEventsYet);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcUpcoming),
      for (final e in list)
        _row(context, dot: _hex(e['color_code']), main: '${e['event_name'] ?? ''}', side: _date(e), onTap: () => _openKey(context, ref, 'tlev_${e['id']}')),
    ]);
  },
);

// ── locator ─────────────────────────────────────────────────────────────
final _pinlist = (
  (Database db, ComponentCtx ctx) async => db.rawQuery('''
    SELECT a.id, a.area_name, c.color_code FROM map_area a JOIN map m ON a.map_id=m.id
    LEFT JOIN use_color c ON a.color=c.id WHERE m.module_ref=? ORDER BY a.id''', [ctx.source.id]),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final areas = d as List<Map<String, Object?>>;
    if (areas.isEmpty) return _empty(context, AppLocalizations.of(context)!.mapNoAreas);
    return Column(children: [
      for (final a in areas)
        _row(context, dot: _hex(a['color_code']), main: '${a['area_name'] ?? '—'}', onTap: () => _openModule(context, ctx, ctx.source.id)),
    ]);
  },
);

// ── author ──────────────────────────────────────────────────────────────
Future<List<Map<String, Object?>>> _chaptersOf(Database db, int moduleId) => db.rawQuery(
    'SELECT id, name, chapter_label, chapter_content, status FROM book_chapter WHERE module_ref=? ORDER BY chapter_order, id', [moduleId]);

int words(String? html) => (html ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

final _progress = (
  (Database db, ComponentCtx ctx) async => _chaptersOf(db, ctx.source.id),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final chs = d as List<Map<String, Object?>>;
    if (chs.isEmpty) return _empty(context, l10n.pcNoChapters);
    final rows = [
      for (final c in chs)
        ('${c['chapter_label'] != null && '${c['chapter_label']}'.isNotEmpty ? '${c['chapter_label']} · ' : ''}${c['name']}', words(c['chapter_content'] as String?), null),
    ];
    final total = rows.fold<int>(0, (s, r) => s + r.$2);
    final goal = (optValue(ctx.block, 'goal') as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('$total', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(l10n.pcWords, style: TextStyle(color: context.ddx.textMuted)),
        const Spacer(),
        if (goal > 0) Text('${min(100, (total * 100 / goal).round())}% · $goal', style: TextStyle(color: context.ddx.textMuted)),
      ]),
      const SizedBox(height: 6),
      _bars(context, rows),
    ]);
  },
);

final _chapters = (
  (Database db, ComponentCtx ctx) async => _chaptersOf(db, ctx.source.id),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final chs = d as List<Map<String, Object?>>;
    if (chs.isEmpty) return _empty(context, AppLocalizations.of(context)!.pcNoChapters);
    return Column(children: [
      for (final c in chs)
        _row(context,
            lead: SizedBox(width: 32, child: Text('${c['chapter_label'] ?? ''}', style: TextStyle(color: context.ddx.textMuted))),
            main: '${c['name']}',
            side: '${c['status'] ?? ''}',
            onTap: () => _openKey(context, ref, 'bchp_${c['id']}')),
    ]);
  },
);

// ── narrator ────────────────────────────────────────────────────────────
final _endings = (
  (Database db, ComponentCtx ctx) async => db.rawQuery('''
    SELECT d.id, d.name, c.color_code FROM story_dialogue d LEFT JOIN use_color c ON d.color=c.id
    WHERE d.module_ref=? AND d.id NOT IN (SELECT from_ref FROM story_edge WHERE module_ref=?) ORDER BY d.id''', [ctx.source.id, ctx.source.id]),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final ends = d as List<Map<String, Object?>>;
    if (ends.isEmpty) return _empty(context, l10n.pcNoEndings);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcEndings),
      for (final e in ends) _row(context, dot: _hex(e['color_code']), main: '${e['name']}', onTap: () => _openKey(context, ref, 'sdlg_${e['id']}')),
    ]);
  },
);

/// The story's variables (EXE narrator.js getStoryVariables): the objects
/// of any Classifier made from the "story variables" preset — its fields
/// marked by options.role varType / varDefault.
final _variables = (
  (Database db, ComponentCtx ctx) async {
    final out = <(String, String, String)>[];
    for (final m in await db.rawQuery("SELECT id FROM module WHERE nexus_ref=? AND kind='classifier' ORDER BY display_order, id", [ctx.nexusId])) {
      final def = await db.rawQuery(
          "SELECT id FROM classifier_template WHERE module_ref=? AND object_ref IS NULL AND options LIKE '%\"role\":\"varDefault\"%' ORDER BY id LIMIT 1", [m['id']]);
      if (def.isEmpty) continue;
      for (final o in await db.rawQuery('SELECT id, name FROM classifier_object WHERE module_ref=? ORDER BY display_order, id', [m['id']])) {
        final v = await db.rawQuery('SELECT attribute_value AS v FROM classifier_attribute WHERE object_ref=? AND template_ref=?', [o['id'], def.first['id']]);
        out.add(('cobj_${o['id']}', '${o['name']}', v.isEmpty ? '' : '${v.first['v'] ?? ''}'));
      }
    }
    return out;
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final vars = d as List<(String, String, String)>;
    if (vars.isEmpty) return _empty(context, l10n.pcNoVariables);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcVariables),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (key, name, initial) in vars.take(30))
          ActionChip(label: Text('$name = $initial'), onPressed: () => _openKey(context, ref, key)),
      ]),
    ]);
  },
);

// ── exhibitor ───────────────────────────────────────────────────────────
Future<List<Map<String, Object?>>> _relations(Database db, int nexusId) => db.rawQuery(
    'SELECT r.from_key, r.to_key, r.label, c.color_code FROM entity_relation r LEFT JOIN use_color c ON r.color=c.id WHERE r.nexus_ref=? ORDER BY r.id',
    [nexusId]);

final _focus = (
  (Database db, ComponentCtx ctx) async => _relations(db, ctx.nexusId),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final rels = d as List<Map<String, Object?>>;
    if (rels.isEmpty) return _empty(context, l10n.pcNoRelations);
    final index = ref.watch(nexusIndexProvider(ctx.nexusId)).valueOrNull ?? const [];
    String name(String k) => index.where((e) => e.key == k).firstOrNull?.name ?? k;
    final deg = <String, int>{};
    for (final r in rels) {
      for (final k in [r['from_key'] as String, r['to_key'] as String]) {
        deg[k] = (deg[k] ?? 0) + 1;
      }
    }
    final want = ctx.block.config['center'];
    final center = want is String && deg.containsKey(want) ? want : (deg.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final ties = rels.where((r) => r['from_key'] == center || r['to_key'] == center).take(16);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: ActionChip(label: Text(name(center), style: const TextStyle(fontWeight: FontWeight.w700)), onPressed: () => _openKey(context, ref, center))),
      for (final r in ties)
        () {
          final other = r['from_key'] == center ? r['to_key'] as String : r['from_key'] as String;
          return _row(context, dot: _hex(r['color_code']), main: name(other), side: '${r['label'] ?? ''}', onTap: () => _openKey(context, ref, other));
        }(),
    ]);
  },
);

final _legend = (
  (Database db, ComponentCtx ctx) async => _relations(db, ctx.nexusId),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final rels = d as List<Map<String, Object?>>;
    if (rels.isEmpty) return _empty(context, l10n.pcNoRelations);
    final by = <String, (int, Color?)>{};
    for (final r in rels) {
      final k = '${r['label'] ?? ''}'.isEmpty ? l10n.pcUnlabelled : '${r['label']}';
      by[k] = ((by[k]?.$1 ?? 0) + 1, by[k]?.$2 ?? _hex(r['color_code']));
    }
    final rows = by.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcLegend),
      _bars(context, [for (final e in rows.take(12)) (e.key, e.value.$1, e.value.$2)]),
    ]);
  },
);

// ── wanderer ────────────────────────────────────────────────────────────
final _journey = (
  (Database db, ComponentCtx ctx) async => db.rawQuery('''
    SELECT me.id, me.label, me.event_ref, te.event_name, c.color_code AS event_color_code,
      s.day s_day, s.month s_month, s.years s_years
    FROM map_event me LEFT JOIN timeline_event te ON me.event_ref=te.id
    LEFT JOIN timeline_date s ON te.start_at=s.id LEFT JOIN use_color c ON te.color=c.id
    WHERE me.module_ref=?
    ORDER BY CASE WHEN s.years IS NULL THEN 1 ELSE 0 END, s.years, s.month, s.day, me.id''', [ctx.source.id]),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final pins = d as List<Map<String, Object?>>;
    if (pins.isEmpty) return _empty(context, AppLocalizations.of(context)!.wandererPlaceHint);
    return Column(children: [
      for (final p in pins)
        _row(context,
            dot: _hex(p['event_color_code']),
            main: '${p['label'] ?? p['event_name'] ?? '—'}',
            sub: p['label'] != null && p['event_name'] != null ? '${p['event_name']}' : null,
            side: _date(p),
            onTap: p['event_ref'] == null ? null : () => _openKey(context, ref, 'tlev_${p['event_ref']}')),
    ]);
  },
);

// ── designer ────────────────────────────────────────────────────────────
final _strip = (
  (Database db, ComponentCtx ctx) async {
    final nodes = await db.rawQuery('SELECT id, node_text, color, read_order FROM design_node WHERE module_ref=? ORDER BY id', [ctx.source.id]);
    final ordered = nodes.where((n) => n['read_order'] != null).toList()..sort((a, b) => (a['read_order'] as num).compareTo(b['read_order'] as num));
    return (ordered.isNotEmpty ? ordered : nodes).take(24).toList();
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final list = d as List<Map<String, Object?>>;
    if (list.isEmpty) return _empty(context, AppLocalizations.of(context)!.pcNoPanels);
    return SizedBox(
      height: 110,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final (i, n) in list.indexed)
          InkWell(
            onTap: () => _openModule(context, ctx, ctx.source.id),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _hex(n['color']) ?? Theme.of(context).dividerColor, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${n['read_order'] ?? i + 1}', style: TextStyle(fontSize: 11, color: context.ddx.textMuted)),
                Expanded(child: Text('${n['node_text'] ?? ''}', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              ]),
            ),
          ),
      ]),
    );
  },
);

// ── sketcher ────────────────────────────────────────────────────────────
final _featured = (
  (Database db, ComponentCtx ctx) async {
    final pages = await db.rawQuery(
        'SELECT p.id, p.name, (SELECT COUNT(*) FROM sketch_stroke s WHERE s.page_ref=p.id) AS strokes FROM sketch_page p WHERE p.module_ref=? ORDER BY p.page_order, p.id',
        [ctx.source.id]);
    if (pages.isEmpty) return null;
    final want = int.tryParse('${ctx.block.config['page'] ?? ''}');
    return (pages.where((p) => p['id'] == want).firstOrNull ?? pages.first, pages.length);
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    if (d == null) return _empty(context, l10n.pcNoSketches);
    final (p, n) = d as (Map<String, Object?>, int);
    return InkWell(
      onTap: () => _openModule(context, ctx, ctx.source.id),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.draw_outlined, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.pcFeatured.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: .8, color: context.ddx.textMuted)),
            Text('${p['name']}', style: Theme.of(context).textTheme.titleMedium),
            Text('$n · ${p['strokes'] ?? 0}', style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
          ]),
        ),
      ]),
    );
  },
);

// ── manager ─────────────────────────────────────────────────────────────
/// The modules a Manager's selection names — its filter over the Nexus
/// index, the same rows its own view shows.
Future<List<Map<String, Object?>>> _managed(Database db, ComponentCtx ctx) async {
  final picks = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='managerPicks'", [ctx.source.id]);
  List<int> ids = const [];
  try {
    final v = jsonDecode(picks.isEmpty ? '[]' : '${picks.first['ui_value'] ?? '[]'}');
    if (v is List) ids = [for (final x in v) ?int.tryParse('$x')];
  } catch (_) {}
  final rows = ids.isNotEmpty
      ? await db.rawQuery('SELECT id, name, kind, update_at FROM module WHERE id IN (${List.filled(ids.length, '?').join(',')})', ids)
      : await db.rawQuery('SELECT id, name, kind, update_at FROM module WHERE parent_id=? ORDER BY display_order, id', [ctx.source.id]);
  return rows;
}

final _dashboard = (
  (Database db, ComponentCtx ctx) async {
    final out = <(Map<String, Object?>, int)>[];
    for (final r in (await _managed(db, ctx)).take(12)) {
      final n = (await db.rawQuery('''
        SELECT (SELECT COUNT(*) FROM classifier_object WHERE module_ref=?1) + (SELECT COUNT(*) FROM book_chapter WHERE module_ref=?1)
             + (SELECT COUNT(*) FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id WHERE tl.module_ref=?1) AS n''', [r['id']])).first['n'] as int;
      out.add((r, n));
    }
    return out;
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final rows = d as List<(Map<String, Object?>, int)>;
    if (rows.isEmpty) return _empty(context, AppLocalizations.of(context)!.managerEmpty);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (r, n) in rows)
        SizedBox(
          width: 150,
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _openModule(context, ctx, r['id'] as int),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Icon(moduleKindInfo[ModuleKind.fromId('${r['kind']}')]?.icon ?? Icons.folder_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${r['name']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Text('$n', style: TextStyle(color: context.ddx.textMuted)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  },
);

final _recent = (
  (Database db, ComponentCtx ctx) async =>
      ((await _managed(db, ctx)).where((r) => '${r['update_at'] ?? ''}'.isNotEmpty).toList()
            ..sort((a, b) => '${b['update_at']}'.compareTo('${a['update_at']}')))
          .take(6)
          .toList(),
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final rows = d as List<Map<String, Object?>>;
    if (rows.isEmpty) return _empty(context, l10n.managerEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcRecent),
      for (final r in rows)
        _row(context,
            lead: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(moduleKindInfo[ModuleKind.fromId('${r['kind']}')]?.icon ?? Icons.folder_outlined, size: 18)),
            main: '${r['name']}',
            side: '${r['update_at']}'.substring(0, min(10, '${r['update_at']}'.length)),
            onTap: () => _openModule(context, ctx, r['id'] as int)),
    ]);
  },
);

// ── diviner ─────────────────────────────────────────────────────────────
/// Quick roll: pick a table, roll, see the last five.
class _QuickRoll extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const _QuickRoll({required this.ctx});

  @override
  ConsumerState<_QuickRoll> createState() => _QuickRollState();
}

class _QuickRollState extends ConsumerState<_QuickRoll> {
  int? _table;
  int _tick = 0;

  Future<(List<Map<String, Object?>>, List<Map<String, Object?>>)> _load() async {
    final db = await ref.read(databaseProvider.future);
    final tables = await db.rawQuery('SELECT id, name FROM diviner_table WHERE module_ref=? ORDER BY display_order, id', [widget.ctx.source.id]);
    final cur = tables.where((t) => t['id'] == _table).firstOrNull ?? tables.firstOrNull;
    final rolls = cur == null
        ? <Map<String, Object?>>[]
        : await db.rawQuery('SELECT result_text, dice_result FROM diviner_roll WHERE table_ref=? ORDER BY id DESC LIMIT 5', [cur['id']]);
    _table = cur?['id'] as int?;
    return (tables, rolls);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder(
      key: ValueKey(_tick),
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 48);
        final (tables, rolls) = snap.data!;
        if (tables.isEmpty) return _empty(context, l10n.divNoEntries);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _table,
                items: [for (final t in tables) DropdownMenuItem(value: t['id'] as int, child: Text('${t['name']}'))],
                onChanged: (v) => setState(() {
                  _table = v;
                  _tick++;
                }),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: Text(l10n.pcRoll),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final db = await ref.read(databaseProvider.future);
                final r = await DivinerDao(db).roll(_table!);
                messenger.showSnackBar(SnackBar(content: Text(r.text.isEmpty ? '—' : r.text)));
                setState(() => _tick++);
              },
            ),
          ]),
          if (rolls.isEmpty) _empty(context, l10n.pcNoRolls),
          for (final r in rolls) _row(context, main: '${r['result_text'] ?? r['dice_result'] ?? ''}'),
        ]);
      },
    );
  }
}

// ── scribe ──────────────────────────────────────────────────────────────
/// Pinned: messages that start with 📌 — a pin is part of the text, so it
/// travels with a copy or an export.
final _pinned = (
  (Database db, ComponentCtx ctx) async {
    final rows = await db.rawQuery('''
      SELECT m.message FROM chat_message m JOIN chat_session s ON m.session_ref=s.id
      WHERE s.module_ref=? ORDER BY s.session_order, s.id, m.id''', [ctx.source.id]);
    final pinned = [for (final r in rows) if (RegExp(r'^\s*📌').hasMatch('${r['message'] ?? ''}')) '${r['message']}'.replaceFirst(RegExp(r'^\s*📌\s*'), '')];
    return pinned.length > 8 ? pinned.sublist(pinned.length - 8) : pinned;
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final list = d as List<String>;
    if (list.isEmpty) return _empty(context, l10n.pcNoPinned);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, l10n.pcPinned),
      for (final m in list) _row(context, lead: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.push_pin_outlined, size: 16)), main: m),
    ]);
  },
);

// ── drafter ─────────────────────────────────────────────────────────────
/// Tasks: every "- [ ]" line in the notes, done ones struck through.
List<(bool, String)> tasksOf(String? description) => [
      for (final l in (description ?? '')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</(p|div|li)>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .split('\n'))
        if (RegExp(r'^\s*[-*]\s*\[( |x|X)\]\s*(.+)$').firstMatch(l) case final m?) (m[1] != ' ', m[2]!),
    ];

final _tasks = (
  (Database db, ComponentCtx ctx) async {
    final r = await db.rawQuery('SELECT description FROM module WHERE id=?', [ctx.source.id]);
    return tasksOf(r.isEmpty ? null : r.first['description'] as String?);
  },
  (BuildContext context, WidgetRef ref, ComponentCtx ctx, Object? d) {
    final l10n = AppLocalizations.of(context)!;
    final tasks = d as List<(bool, String)>;
    if (tasks.isEmpty) return _empty(context, l10n.pcNoTasks);
    final open = tasks.where((t) => !t.$1).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(context, '${l10n.pcTasks} · $open/${tasks.length}'),
      for (final (done, text) in tasks)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(done ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 18, color: context.ddx.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(decoration: done ? TextDecoration.lineThrough : null, color: done ? context.ddx.textMuted : null)),
            ),
          ]),
        ),
    ]);
  },
);

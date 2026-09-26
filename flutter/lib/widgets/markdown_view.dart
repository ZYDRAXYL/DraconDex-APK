import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../core/i18n/app_localizations.dart';
import '../data/dao/module_dao.dart';
import '../data/models/module_model.dart';
import '../data/models/recent_view_model.dart';
import '../data/services/entity_location.dart';
import '../data/services/wiki_service.dart';
import '../providers/db_providers.dart';
import '../providers/navigation_providers.dart';

/// Footnotes across one page (APP docs/TEMPLATES.md §7.4; EXE markdown.js
/// mdFootnotes, blocks.js pbFootnoteCtx): `[^id]` is numbered by where it is
/// first referenced on the page, and `[^id]: text` defines it. With a
/// References block on the page the definitions are listed there and not
/// under their text.
class Footnotes {
  static final refRe = RegExp(r'\[\^([A-Za-z0-9_-]{1,20})\]');
  static final defRe = RegExp(r'^\[\^([A-Za-z0-9_-]{1,20})\]:\s?(.*)$');

  final Map<String, String> notes;
  final List<String> order;
  final bool hideDefs;
  const Footnotes(this.notes, this.order, {this.hideDefs = false});

  /// From texts in page order; fenced code is skipped.
  factory Footnotes.of(Iterable<String> texts, {bool hideDefs = false}) {
    final notes = <String, String>{};
    final order = <String>[];
    for (final text in texts) {
      var fenced = false;
      for (final line in text.split('\n')) {
        if (line.startsWith('```')) {
          fenced = !fenced;
          continue;
        }
        if (fenced) continue;
        final d = defRe.firstMatch(line);
        if (d != null) {
          notes.putIfAbsent(d[1]!, () => d[2]!.trim());
          continue;
        }
        for (final m in refRe.allMatches(line.replaceAll(RegExp(r'`[^`\n]+`'), ''))) {
          if (!order.contains(m[1])) order.add(m[1]!);
        }
      }
    }
    return Footnotes(notes, order, hideDefs: hideDefs);
  }

  /// The number a reference shows; '?' for one never referenced.
  String number(String id) {
    final n = order.indexOf(id);
    return n < 0 ? '?' : '${n + 1}';
  }
}

/// The page's footnotes, for every MarkdownView under it.
class FootnoteScope extends InheritedWidget {
  final Footnotes footnotes;
  const FootnoteScope({super.key, required this.footnotes, required super.child});

  static Footnotes? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FootnoteScope>()?.footnotes;

  @override
  bool updateShouldNotify(FootnoteScope old) =>
      old.footnotes.order.join('\u0000') != footnotes.order.join('\u0000') ||
      old.footnotes.hideDefs != footnotes.hideDefs ||
      old.footnotes.notes.toString() != footnotes.notes.toString();
}

/// Markdown as the desktop writes it (mdRender, EXE renderer/markdown.js), at
/// the size a phone page needs: headings (#, ##, ###), bullet and numbered
/// lists, block quotes, **bold**, *italic*, `code` — and `[[wiki links]]`
/// (APP docs/APK-V3.md §6). A resolved link opens its page; an unresolved
/// one is drawn dimmed and offers to make a Drafter with that name, the
/// desktop's same offer.
class MarkdownView extends ConsumerWidget {
  final String text;
  final int nexusId;
  final TextStyle? style;

  const MarkdownView({super.key, required this.text, required this.nexusId, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium!;
    final notes = FootnoteScope.of(context) ?? Footnotes.of([text]);
    final blocks = <Widget>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final def = Footnotes.defRe.firstMatch(line);
      if (def != null) {
        // listed by the References block when there is one; under the text
        // otherwise, small, as the note it is
        if (!notes.hideDefs) {
          blocks.add(Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _rich(context, ref, '${notes.number(def[1]!)}. ${def[2]}', base.copyWith(fontSize: (base.fontSize ?? 14) * .85)),
          ));
        }
        continue;
      }
      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
      } else if (h != null) {
        final level = h.group(1)!.length;
        final hs = [theme.textTheme.titleLarge, theme.textTheme.titleMedium, theme.textTheme.titleSmall][level - 1];
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: _rich(context, ref, h.group(2)!, hs!.copyWith(fontWeight: FontWeight.w600)),
        ));
      } else if (bullet != null || numbered != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(bullet != null ? '•' : '${numbered!.group(1)}.', style: base)),
              Expanded(child: _rich(context, ref, bullet?.group(1) ?? numbered!.group(2)!, base)),
            ],
          ),
        ));
      } else if (quote != null) {
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.dividerColor, width: 3))),
          child: _rich(context, ref, quote.group(1)!, base.copyWith(fontStyle: FontStyle.italic)),
        ));
      } else {
        blocks.add(Padding(padding: const EdgeInsets.only(bottom: 2), child: _rich(context, ref, line, base)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
  }

  Widget _rich(BuildContext context, WidgetRef ref, String line, TextStyle style) =>
      Text.rich(TextSpan(style: style, children: inlineSpans(context, ref, line, style)));

  static final _inlineRe =
      RegExp(r'\[\[([^\[\]|]+?)(?:\|([^\[\]]+?))?\]\]|\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`|\[\^([A-Za-z0-9_-]{1,20})\]');

  List<InlineSpan> inlineSpans(BuildContext context, WidgetRef ref, String line, TextStyle style) {
    final scheme = Theme.of(context).colorScheme;
    final index = ref.watch(nexusIndexProvider(nexusId)).valueOrNull;
    final names = {for (final it in index ?? const []) it.name.toLowerCase()};
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _inlineRe.allMatches(line)) {
      if (m.start > at) out.add(TextSpan(text: line.substring(at, m.start)));
      if (m.group(1) != null) {
        final link = WikiLinkMatch(m.start, m.end, m.group(1)!.trim(), m.group(2)?.trim());
        // Known from the index when it has loaded; an unknown name is only
        // dimmed once the index says so, so nothing flickers while it loads.
        final known = index == null || names.contains(link.label.toLowerCase()) || link.name.contains(':');
        final linkStyle = style.copyWith(
          color: known ? scheme.primary : scheme.primary.withValues(alpha: 0.5),
          decoration: TextDecoration.underline,
          decorationColor: known ? scheme.primary : scheme.primary.withValues(alpha: 0.5),
          decorationStyle: known ? TextDecorationStyle.solid : TextDecorationStyle.dashed,
        );
        // a tap opens it; a long press shows what is there first (the
        // desktop's hover card, APP docs/TEMPLATES.md §7.5)
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            link: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openWikiLink(context, ref, link.name, nexusId),
              onLongPress: () => showLinkPreview(context, ref, link.name, nexusId),
              child: Text(link.label, style: linkStyle),
            ),
          ),
        ));
      } else if (m.group(3) != null) {
        out.add(TextSpan(text: m.group(3), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(4) != null) {
        out.add(TextSpan(text: m.group(4), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (m.group(6) != null) {
        final id = m.group(6)!;
        final notes = FootnoteScope.of(context) ?? Footnotes.of([text]);
        out.add(TextSpan(
          text: '[${notes.number(id)}]',
          style: TextStyle(color: scheme.primary, fontSize: (style.fontSize ?? 14) * .8, fontFeatures: const [FontFeature.superscripts()]),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final note = notes.notes[id];
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(note == null || note.isEmpty ? AppLocalizations.of(context)!.pbFootnoteMissing : '${notes.number(id)}. $note'),
              ));
            },
        ));
      } else {
        out.add(TextSpan(
          text: m.group(5),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: scheme.surfaceContainerHighest),
        ));
      }
      at = m.end;
    }
    if (at < line.length) out.add(TextSpan(text: line.substring(at)));
    return out;
  }
}

/// Opens what `[[name]]` names, or offers to create a Drafter called that.
Future<void> openWikiLink(BuildContext context, WidgetRef ref, String name, int nexusId) async {
  final router = GoRouter.of(context);
  final l10n = AppLocalizations.of(context)!;
  final db = await ref.read(databaseProvider.future);
  final key = await WikiService.resolveName(db, name, nexusId);
  final location = key == null ? null : await EntityLocation.of(db, key);
  if (location != null) {
    router.push(location);
    return;
  }
  if (!context.mounted) return;
  final label = name.replaceFirst(RegExp(r'^\w+:'), '');
  final create = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: Text(l10n.wikiUnresolved),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.wikiCreateDrafter)),
      ],
    ),
  );
  if (create != true) return;
  final id = await ModuleDao(db).createModule(nexusRef: nexusId, name: label, kind: ModuleKind.drafter);
  ref.invalidate(nexusIndexProvider(nexusId));
  router.push(RecentView.locationFor(nexusId, id));
}

/// What a `[[link]]` points at, before going there: its name, where it
/// lives and the start of its text — the phone's long press for the
/// desktop's hover card.
Future<void> showLinkPreview(BuildContext context, WidgetRef ref, String name, int nexusId) async {
  final l10n = AppLocalizations.of(context)!;
  final db = await ref.read(databaseProvider.future);
  final key = await WikiService.resolveName(db, name, nexusId);
  final index = await ref.read(nexusIndexProvider(nexusId).future);
  final item = key == null ? null : index.where((e) => e.key == key).firstOrNull;
  final snippet = key == null ? '' : await linkPreviewText(db, key);
  if (!context.mounted) return;
  final theme = Theme.of(context);
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(item?.name ?? name.replaceFirst(RegExp(r'^\w+:'), ''), style: theme.textTheme.titleMedium),
          if (item != null && item.itemKind != 'module')
            Text(item.moduleName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (key == null)
            Text(l10n.wikiUnresolved)
          else if (snippet.isNotEmpty)
            Text(snippet, maxLines: 8, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(sheet);
                openWikiLink(context, ref, name, nexusId);
              },
              child: Text(key == null ? l10n.wikiCreateDrafter : l10n.rowOpen),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// The first few hundred characters of an entity's own text, markup
/// removed — a chapter, an element's note, an event's story, a module's
/// description.
Future<String> linkPreviewText(DatabaseExecutor db, String key) async {
  final m = RegExp(r'^([a-z]+)_(\d+)$').firstMatch(key);
  if (m == null) return '';
  final sql = switch (m[1]) {
    'module' => 'SELECT description AS t FROM module WHERE id=?',
    'cobj' => 'SELECT note AS t FROM classifier_object WHERE id=?',
    'bchp' => 'SELECT COALESCE(synopsis, chapter_content) AS t FROM book_chapter WHERE id=?',
    'tlev' => 'SELECT story AS t FROM timeline_event WHERE id=?',
    _ => null,
  };
  if (sql == null) return '';
  final r = await db.rawQuery(sql, [int.parse(m[2]!)]);
  final raw = r.isEmpty ? '' : '${r.first['t'] ?? ''}';
  final plain = raw
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAllMapped(RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'), (x) => x[2] ?? x[1]!)
      .replaceAll(RegExp(r'[#*_`>]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.length > 400 ? '${plain.substring(0, 400)}…' : plain;
}

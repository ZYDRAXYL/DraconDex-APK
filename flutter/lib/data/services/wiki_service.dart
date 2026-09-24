import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';

/// One `[[Name]]` or `[[Name|alias]]` found in a text.
class WikiLinkMatch {
  final int start;
  final int end;

  /// What the link names — possibly with a `ns:` prefix (`[[file:x.png]]`).
  final String name;

  /// The text to show instead of [name], when the link gives one.
  final String? alias;

  const WikiLinkMatch(this.start, this.end, this.name, this.alias);

  String get label => alias ?? name.replaceFirst(RegExp(r'^\w+:'), '');
}

/// A text field that can hold `[[links]]` — one per source-key prefix, the
/// port of an entry in EXE `db/wiki-sources.js` CONTENT_SOURCES:
///   [content]  the field's current text, as indexed
///   [rewrite]  run `apply` over the stored text, write back what changed,
///              return the new indexed content (null when nothing changed) —
///              how a rename of a link's TARGET reaches back into this field
///   [rebuild]  every row worth indexing: `id, nexus_ref, c`
class ContentSource {
  final Future<String> Function(DatabaseExecutor db, int id) content;
  final Future<String?> Function(DatabaseExecutor db, int id, String Function(String) apply) rewrite;
  final String rebuild;

  /// The row's `c` is not the whole text (a module's blocks, a Classifier
  /// object's fields): re-read it through [content].
  final bool rebuildReadsContent;

  /// The vault of one row: `SELECT … AS n … WHERE id=?`.
  final String nexusOf;

  const ContentSource({
    required this.content,
    required this.rewrite,
    required this.rebuild,
    required this.nexusOf,
    this.rebuildReadsContent = false,
  });
}

/// The wiki-link index (APP docs/APK-V3.md §6, V5.md §8.4) — the port of EXE
/// `db/wiki.js` + `db/wiki-sources.js`. The text is the source of truth;
/// `wiki_link` is a rebuildable index of which source names which target,
/// so backlinks, the Problems list and a rename can find them.
///
/// Name resolution runs the same resolvers in the same order as the desktop:
/// note, then the read-only legacy families, then every ENTITY_KINDS family
/// with a `wiki` facet in declared order, `file` last — so `[[Name]]` means
/// the same thing on both apps. A `ns:` prefix forces one resolver.
class WikiService {
  /// Keep in step with EXE `WIKILINK_RE` (db/wiki.js) and `MD_WIKILINK_RE`.
  static final linkRe = RegExp(r'\[\[([^\[\]|]+?)(?:\|([^\[\]]+?))?\]\]');

  static List<WikiLinkMatch> parse(String text) => [
        for (final m in linkRe.allMatches(text))
          if (m.group(1)!.trim().isNotEmpty) WikiLinkMatch(m.start, m.end, m.group(1)!.trim(), m.group(2)?.trim()),
      ];

  // ── resolvers ────────────────────────────────────────────────────────────
  static const _legacy = <(String, String)>[
    ('obj', 'SELECT o.id FROM object o JOIN project p ON o.project_id=p.id WHERE (? IS NULL OR p.nexus_ref=?) AND o.name=? COLLATE NOCASE'),
    ('wchar', 'SELECT c.id FROM world_character c JOIN world_project w ON c.world_ref=w.id WHERE (? IS NULL OR w.nexus_ref=?) AND c.name=? COLLATE NOCASE'),
    ('wobj', 'SELECT o.id FROM world_orig_object o JOIN world_orig_category c ON o.category_id=c.id JOIN world_project w ON c.world_ref=w.id WHERE (? IS NULL OR w.nexus_ref=?) AND o.name=? COLLATE NOCASE'),
    ('gchar', 'SELECT c.id FROM game_character c JOIN game_project g ON c.game_ref=g.id WHERE (? IS NULL OR g.nexus_ref=?) AND c.name=? COLLATE NOCASE'),
    ('gel', 'SELECT e.id FROM game_col_element e JOIN game_collection c ON e.collection_ref=c.id JOIN game_project g ON c.game_ref=g.id WHERE (? IS NULL OR g.nexus_ref=?) AND e.name=? COLLATE NOCASE'),
    ('wchp', 'SELECT ch.id FROM write_chapter ch JOIN write_book b ON ch.book_id=b.id JOIN write_series s ON b.series_id=s.id JOIN write_project p ON s.project_id=p.id WHERE (? IS NULL OR p.nexus_ref=?) AND ch.name=? COLLATE NOCASE'),
    ('wnote', 'SELECT wn.id FROM write_note wn JOIN write_project p ON wn.project_id=p.id WHERE (? IS NULL OR p.nexus_ref=?) AND wn.notename=? COLLATE NOCASE'),
    ('proj', 'SELECT id FROM project WHERE (? IS NULL OR nexus_ref=?) AND name=? COLLATE NOCASE'),
    ('world', 'SELECT id FROM world_project WHERE (? IS NULL OR nexus_ref=?) AND name=? COLLATE NOCASE'),
    ('game', 'SELECT id FROM game_project WHERE (? IS NULL OR nexus_ref=?) AND name=? COLLATE NOCASE'),
    ('write', 'SELECT id FROM write_project WHERE (? IS NULL OR nexus_ref=?) AND project_name=? COLLATE NOCASE'),
  ];

  /// (prefix, SQL taking (nexus, nexus, name)), in resolver order.
  static final List<(String, String)> resolvers = [
    for (final f in entityFamilies)
      if (f.prefix == 'note' && f.wiki != null) (f.prefix, f.wiki!),
    ..._legacy,
    for (final f in entityFamilies)
      if (f.prefix != 'note' && f.prefix != 'file' && f.wiki != null) (f.prefix, f.wiki!),
    for (final f in entityFamilies)
      if (f.prefix == 'file' && f.wiki != null) (f.prefix, f.wiki!),
  ];

  /// `[[Name]]` → `prefix_id`, or null. [memo] is for one bulk operation
  /// only — creating or renaming anything changes what a name means.
  static Future<String?> resolveName(DatabaseExecutor db, String raw, int? nexusId,
      {Map<String, String?>? memo}) async {
    final name = raw.trim();
    if (name.isEmpty) return null;
    final memoKey = '$nexusId::${name.toLowerCase()}';
    if (memo != null && memo.containsKey(memoKey)) return memo[memoKey];
    String? out;
    final forced = RegExp(r'^(\w+):(.+)$').firstMatch(name);
    final forcedNs = forced?.group(1)!.toLowerCase();
    final forcedResolver = forcedNs == null ? null : resolvers.where((r) => r.$1 == forcedNs).firstOrNull;
    if (forcedResolver != null) {
      final id = await _run(db, forcedResolver.$2, forced!.group(2)!.trim(), nexusId);
      out = id == null ? null : '${forcedResolver.$1}_$id';
    } else {
      for (final (prefix, sql) in resolvers) {
        final id = await _run(db, sql, name, nexusId);
        if (id != null) {
          out = '${prefix}_$id';
          break;
        }
      }
    }
    memo?[memoKey] = out;
    return out;
  }

  static Future<int?> _run(DatabaseExecutor db, String sql, String name, int? nx) async {
    try {
      final r = await db.rawQuery(sql, [nx, nx, name]);
      return r.isEmpty ? null : r.first['id'] as int?;
    } catch (_) {
      return null; // a legacy table this vault does not have
    }
  }

  // ── sources ──────────────────────────────────────────────────────────────
  static ContentSource _column(String table, String col, String rebuild, String nexusOf) => ContentSource(
        content: (db, id) async =>
            (await db.rawQuery('SELECT $col AS c FROM $table WHERE id=?', [id])).firstOrNull?['c'] as String? ?? '',
        rewrite: (db, id, apply) async {
          final cur = (await db.rawQuery('SELECT $col AS c FROM $table WHERE id=?', [id])).firstOrNull?['c'] as String?;
          if (cur == null || cur.isEmpty) return null;
          final next = apply(cur);
          if (next == cur) return null;
          await db.rawUpdate("UPDATE $table SET $col=?, update_at=datetime('now') WHERE id=?", [next, id]);
          return next;
        },
        rebuild: rebuild,
        nexusOf: nexusOf,
      );

  // A page's text and property blocks index under the page's key: module_<id>
  // for a module page, cobj_<id> for an element page split off the shared
  // layout. The shared layout ('*') is template text and indexes nowhere.
  static String _pageText(String where) => "SELECT id, content AS v FROM page_block WHERE $where "
      "AND block_type IN ('text','property') AND content IS NOT NULL AND content<>'' ORDER BY block_order, id";
  static final _moduleBlocks = _pageText('module_ref=? AND item_key IS NULL');
  static final _itemBlocks = _pageText('item_key=?');
  static const _clsTextAttrs = '''
    SELECT ca.id, ca.attribute_value AS v FROM classifier_attribute ca
    JOIN classifier_template ct ON ct.id=ca.template_ref
    WHERE ca.object_ref=? AND COALESCE(ct.attribute_type,'text') IN ('text','textarea')
    ORDER BY ct.display_order, ct.id''';

  static Future<bool> _rewriteBlocks(DatabaseExecutor db, String sql, Object arg, String Function(String) apply) async {
    var any = false;
    for (final b in await db.rawQuery(sql, [arg])) {
      final v = b['v'] as String;
      final next = apply(v);
      if (next == v) continue;
      await db.rawUpdate("UPDATE page_block SET content=?, update_at=datetime('now') WHERE id=?", [next, b['id']]);
      any = true;
    }
    return any;
  }

  static Future<String> _moduleContent(DatabaseExecutor db, int id) async {
    final desc = (await db.rawQuery('SELECT description FROM module WHERE id=?', [id])).firstOrNull?['description'] as String?;
    final blocks = [for (final b in await db.rawQuery(_moduleBlocks, [id])) b['v'] as String];
    return [desc ?? '', ...blocks].where((s) => s.isNotEmpty).join('\n');
  }

  static Future<String> _objectContent(DatabaseExecutor db, int id) async {
    final note = (await db.rawQuery('SELECT note FROM classifier_object WHERE id=?', [id])).firstOrNull?['note'] as String?;
    final vals = [for (final r in await db.rawQuery(_clsTextAttrs, [id])) (r['v'] as String?) ?? ''];
    final blocks = [for (final b in await db.rawQuery(_itemBlocks, ['cobj_$id'])) b['v'] as String];
    return [note ?? '', ...vals, ...blocks].where((s) => s.isNotEmpty).join('\n');
  }

  static Future<String> _chatContent(DatabaseExecutor db, int id) async =>
      (await db.rawQuery("SELECT COALESCE(GROUP_CONCAT(message, char(10)), '') AS c FROM chat_message WHERE session_ref=?",
              [id]))
          .first['c'] as String? ??
      '';

  static final Map<String, ContentSource> sources = {
    'note': _column('note', 'content', "SELECT id, content AS c, nexus_ref FROM note WHERE content LIKE '%[[%'",
        'SELECT nexus_ref AS n FROM note WHERE id=?'),
    'module': ContentSource(
      content: _moduleContent,
      rewrite: (db, id, apply) async {
        var any = false;
        final cur = (await db.rawQuery('SELECT description FROM module WHERE id=?', [id])).firstOrNull?['description'] as String?;
        if (cur != null && cur.isNotEmpty) {
          final next = apply(cur);
          if (next != cur) {
            await db.rawUpdate("UPDATE module SET description=?, update_at=datetime('now') WHERE id=?", [next, id]);
            any = true;
          }
        }
        if (await _rewriteBlocks(db, _moduleBlocks, id, apply)) any = true;
        return any ? _moduleContent(db, id) : null;
      },
      rebuild: '''
        SELECT m.id, m.nexus_ref, '' AS c FROM module m
        WHERE m.description LIKE '%[[%' OR EXISTS (
          SELECT 1 FROM page_block b WHERE b.module_ref=m.id AND b.item_key IS NULL
            AND b.block_type IN ('text','property') AND b.content LIKE '%[[%')''',
      rebuildReadsContent: true,
      nexusOf: 'SELECT nexus_ref AS n FROM module WHERE id=?',
    ),
    'bchp': _column(
        'book_chapter',
        'chapter_content',
        "SELECT ch.id, ch.chapter_content AS c, m.nexus_ref FROM book_chapter ch JOIN module m ON ch.module_ref=m.id WHERE ch.chapter_content LIKE '%[[%'",
        'SELECT m.nexus_ref AS n FROM book_chapter ch JOIN module m ON ch.module_ref=m.id WHERE ch.id=?'),
    // A chat session's text is its messages, so the rewrite runs per message.
    'chss': ContentSource(
      content: _chatContent,
      rewrite: (db, id, apply) async {
        var any = false;
        for (final g in await db.rawQuery('SELECT id, message FROM chat_message WHERE session_ref=?', [id])) {
          final v = g['message'] as String? ?? '';
          final next = apply(v);
          if (next == v) continue;
          await db.rawUpdate('UPDATE chat_message SET message=? WHERE id=?', [next, g['id']]);
          any = true;
        }
        return any ? _chatContent(db, id) : null;
      },
      rebuild: '''
        SELECT s.id, m.nexus_ref, COALESCE(GROUP_CONCAT(g.message, char(10)), '') AS c
        FROM chat_session s JOIN module m ON s.module_ref=m.id
        JOIN chat_message g ON g.session_ref=s.id
        GROUP BY s.id HAVING c LIKE '%[[%' ''',
      nexusOf: 'SELECT m.nexus_ref AS n FROM chat_session s JOIN module m ON s.module_ref=m.id WHERE s.id=?',
    ),
    // A Classifier object's text: its note, every text/textarea field value
    // and the blocks of its own page — one source key for all of them.
    'cobj': ContentSource(
      content: _objectContent,
      rewrite: (db, id, apply) async {
        var any = false;
        final note = (await db.rawQuery('SELECT note FROM classifier_object WHERE id=?', [id])).firstOrNull?['note'] as String?;
        if (note != null && note.isNotEmpty) {
          final next = apply(note);
          if (next != note) {
            await db.rawUpdate("UPDATE classifier_object SET note=?, update_at=datetime('now') WHERE id=?", [next, id]);
            any = true;
          }
        }
        for (final a in await db.rawQuery(_clsTextAttrs, [id])) {
          final v = a['v'] as String?;
          if (v == null || v.isEmpty) continue;
          final next = apply(v);
          if (next == v) continue;
          await db.rawUpdate("UPDATE classifier_attribute SET attribute_value=?, update_at=datetime('now') WHERE id=?",
              [next, a['id']]);
          any = true;
        }
        if (await _rewriteBlocks(db, _itemBlocks, 'cobj_$id', apply)) any = true;
        return any ? _objectContent(db, id) : null;
      },
      rebuild: '''
        SELECT o.id, m.nexus_ref, '' AS c FROM classifier_object o JOIN module m ON o.module_ref=m.id
        WHERE o.note LIKE '%[[%' OR EXISTS (
          SELECT 1 FROM classifier_attribute ca WHERE ca.object_ref=o.id AND ca.attribute_value LIKE '%[[%')
        OR EXISTS (
          SELECT 1 FROM page_block b WHERE b.item_key='cobj_'||o.id
            AND b.block_type IN ('text','property') AND b.content LIKE '%[[%')''',
      rebuildReadsContent: true,
      nexusOf: 'SELECT m.nexus_ref AS n FROM classifier_object o JOIN module m ON o.module_ref=m.id WHERE o.id=?',
    ),
    'tlev': _column(
        'timeline_event',
        'story',
        "SELECT te.id, te.story AS c, m.nexus_ref FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id JOIN module m ON tl.module_ref=m.id WHERE te.story LIKE '%[[%'",
        'SELECT m.nexus_ref AS n FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id JOIN module m ON tl.module_ref=m.id WHERE te.id=?'),
    'sdlg': _column(
        'story_dialogue',
        'description',
        "SELECT sd.id, sd.description AS c, m.nexus_ref FROM story_dialogue sd JOIN module m ON sd.module_ref=m.id WHERE sd.description LIKE '%[[%'",
        'SELECT m.nexus_ref AS n FROM story_dialogue sd JOIN module m ON sd.module_ref=m.id WHERE sd.id=?'),
    // An Exhibitor note node: its label IS its text.
    'exn': _column(
        'exhibit_node',
        'label',
        "SELECT n.id, n.label AS c, m.nexus_ref FROM exhibit_node n JOIN module m ON n.module_ref=m.id WHERE n.node_type='note' AND n.label LIKE '%[[%'",
        'SELECT m.nexus_ref AS n FROM exhibit_node x JOIN module m ON x.module_ref=m.id WHERE x.id=?'),
  };

  // ── index maintenance ────────────────────────────────────────────────────
  static Future<void> reindexLinks(DatabaseExecutor db, String srcKey, String content, int? nexusId,
      {Map<String, String?>? memo}) async {
    await db.rawDelete('DELETE FROM wiki_link WHERE src_key=?', [srcKey]);
    final seen = <String>{};
    for (final l in parse(content)) {
      if (!seen.add(l.name.toLowerCase())) continue;
      await db.rawInsert('INSERT INTO wiki_link (nexus_ref, src_key, target_key, target_text) VALUES (?,?,?,?)',
          [nexusId, srcKey, await resolveName(db, l.name, nexusId, memo: memo), l.name]);
    }
  }

  /// Re-reads one source's whole indexed text and reindexes it — what every
  /// save of a linkable field calls.
  static Future<void> reindexSource(DatabaseExecutor db, String prefix, int id) async {
    final src = sources[prefix];
    if (src == null) throw ArgumentError('reindexSource: no source $prefix');
    final nx = (await db.rawQuery(src.nexusOf, [id])).firstOrNull?['n'] as int?;
    await reindexLinks(db, '${prefix}_$id', await src.content(db, id), nx);
  }

  /// Rebuilds the whole index from every source — after a snapshot import,
  /// which brings text but not the index.
  static Future<void> rebuildIndex(Database db) async {
    await db.transaction((txn) async {
      final memo = <String, String?>{};
      await txn.rawDelete('DELETE FROM wiki_link');
      for (final e in sources.entries) {
        for (final r in await txn.rawQuery(e.value.rebuild)) {
          final id = r['id'] as int;
          final content = e.value.rebuildReadsContent ? await e.value.content(txn, id) : (r['c'] as String? ?? '');
          await reindexLinks(txn, '${e.key}_$id', content, r['nexus_ref'] as int?, memo: memo);
        }
      }
    });
  }

  /// A new or renamed entity claims the `[[links]]` typed before it had
  /// that name — they were indexed with target_key NULL.
  static Future<int> resolveDangling(DatabaseExecutor db, String name, int? nexusId) async {
    final rows = await db.rawQuery(
        'SELECT id, target_text FROM wiki_link WHERE target_key IS NULL AND (? IS NULL OR nexus_ref=?)', [nexusId, nexusId]);
    String bare(String s) => s.replaceFirst(RegExp(r'^\w+:'), '').trim().toLowerCase();
    final wanted = name.trim().toLowerCase();
    var n = 0;
    for (final r in rows) {
      final text = r['target_text'] as String? ?? '';
      if (bare(text) != wanted) continue;
      final key = await resolveName(db, text, nexusId);
      if (key == null) continue;
      await db.rawUpdate("UPDATE wiki_link SET target_key=?, update_at=datetime('now') WHERE id=?", [key, r['id']]);
      n++;
    }
    return n;
  }

  /// `[[links]]` live in plain text, so renaming a target breaks them: this
  /// rewrites `[[Old]]` / `[[Old|alias]]` / `[[ns:Old]]` in every source that
  /// links [targetKey], then reindexes those sources. Returns how many
  /// sources changed.
  static Future<int> renameTarget(DatabaseExecutor db, String targetKey, String oldName, String newName) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return 0;
    final re = RegExp(r'\[\[((?:\w+:)?)\s*' + RegExp.escape(oldName) + r'\s*(\||\]\])', caseSensitive: false);
    final rows = await db.rawQuery('SELECT DISTINCT src_key, nexus_ref FROM wiki_link WHERE target_key=?', [targetKey]);
    var changed = 0;
    for (final r in rows) {
      final k = EntityKinds.parse(r['src_key']);
      final src = k == null ? null : sources[k.$1];
      if (src == null) continue;
      final next = await src.rewrite(db, k!.$2, (c) => c.replaceAllMapped(re, (m) => '[[${m[1]}$newName${m[2]}'));
      if (next == null) continue;
      await reindexLinks(db, r['src_key'] as String, next, r['nexus_ref'] as int?);
      changed++;
    }
    return changed;
  }

  /// A rename, end to end: rewrite the texts that link the old name, then
  /// let links already written with the new name find it.
  static Future<void> renamed(DatabaseExecutor db, String key, String? oldName, String newName, int? nexusId) async {
    if (oldName != null) await renameTarget(db, key, oldName, newName);
    await resolveDangling(db, newName, nexusId);
  }

  static Future<int?> nexusOfModule(DatabaseExecutor db, int moduleId) async =>
      (await db.rawQuery('SELECT nexus_ref FROM module WHERE id=?', [moduleId])).firstOrNull?['nexus_ref'] as int?;

  /// The sources that link [key], newest first.
  static Future<List<String>> backlinks(DatabaseExecutor db, String key) async => [
        for (final r in await db.rawQuery(
            'SELECT DISTINCT src_key FROM wiki_link WHERE target_key=? ORDER BY update_at DESC, id DESC', [key]))
          r['src_key'] as String,
      ];
}

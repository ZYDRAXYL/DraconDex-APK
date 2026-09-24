import 'dart:collection';

import 'package:sqflite/sqflite.dart';

import '../dao/viewer_dao.dart';
import '../models/recent_view_model.dart';
import '../models/viewer_model.dart';

/// One search result: somewhere the app can go.
class SearchHit {
  final String key;
  final String title;
  final int nexusId;

  /// The module the hit is, or is inside.
  final int moduleId;
  final String moduleName;

  /// The row kind from the vault index — module, object, event, dialogue,
  /// chapter, chat.
  final String itemKind;

  /// For a content hit, the text around the match.
  final String? snippet;

  const SearchHit({
    required this.key,
    required this.title,
    required this.nexusId,
    required this.moduleId,
    required this.moduleName,
    required this.itemKind,
    this.snippet,
  });

  bool get isModule => key.startsWith('module_');

  /// A module opens its page; anything else opens as an element page inside
  /// its module (APP docs/APK-V3.md §10.3).
  String get location =>
      RecentView.locationFor(nexusId, moduleId, isModule ? null : key);
}

/// The one search field of APK V3 (APP docs/APK-V3.md §9.2, §13 items 10 and
/// 14): results in three groups — things (names), content (text) and the
/// app's own commands, which the screen matches itself.
///
/// Content search follows the desktop's rules (V5.md §11.4). An FTS5 table
/// with the `trigram` tokenizer is what Thai needs — it has no spaces to split
/// words at — but whether the phone's SQLite has fts5, and is new enough
/// (3.34) for trigram, depends on the Android version. So it is PROBED at run
/// time, and the index is a TEMP table: it never reaches the vault, a sync,
/// or a snapshot. Without it, and for every query under three characters
/// (which a trigram index cannot answer), the search is a LIKE scan.
///
/// One instance per search screen: the temp index is filled once, the first
/// time a query needs it, so it reflects the vault as it was when the screen
/// opened.
class SearchService {
  final Database db;

  /// null = probe; false forces the LIKE path (tests).
  final bool? useFts;

  SearchService(this.db, {this.useFts});

  static const int _limit = 50;
  static const _ftsTable = 'ddx_search_fts';

  // ---- things -------------------------------------------------------------

  /// Modules and elements whose name contains [query] — or, for `@x`, whose
  /// handle does. Across every Nexus unless [nexusId] is given.
  Future<List<SearchHit>> things(String query, {int? nexusId}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // Ranked as one list, so a prefix match in a later Nexus still comes
    // before a match inside a name in the first.
    final nexusOf = HashMap<IndexedItem, int>.identity();
    for (final n in await _nexusIds(nexusId)) {
      for (final it in await ViewerDao(db).index(n)) {
        nexusOf[it] = n;
      }
    }
    return [
      for (final it in rankItems(nexusOf.keys.toList(), q).take(_limit)) _hitOf(it, nexusOf[it]!),
    ];
  }

  /// Ranks the vault index against what the user typed — the desktop address
  /// row's rules (page/address.js `addrMatches`): `@x` looks at handles,
  /// anything else at names (the last `/` segment of a typed path); a prefix
  /// ranks before a match inside the name. [loose] also accepts the typed
  /// characters in order with gaps, the way the address row does; the search
  /// screen asks for a real substring.
  static List<IndexedItem> rankItems(List<IndexedItem> items, String raw, {bool loose = false}) {
    final text = raw.trim();
    final byHandle = text.startsWith('@');
    final needle = (byHandle ? text.substring(1) : text.split('/').last).trim().toLowerCase();
    if (needle.isEmpty) return const [];
    bool inOrder(String hay) {
      var i = 0;
      for (final ch in hay.split('')) {
        if (i < needle.length && ch == needle[i]) i++;
      }
      return i == needle.length;
    }

    final ranked = <(IndexedItem, int)>[];
    for (final it in items) {
      final hay = ((byHandle ? it.handle : it.name) ?? '').toLowerCase();
      if (hay.isEmpty) continue;
      final rank = hay.startsWith(needle)
          ? 0
          : hay.contains(needle)
              ? 1
              : (loose && inOrder(hay))
                  ? 2
                  : -1;
      if (rank >= 0) ranked.add((it, rank));
    }
    ranked.sort((a, b) {
      final r = a.$2.compareTo(b.$2);
      return r != 0 ? r : a.$1.name.length.compareTo(b.$1.name.length);
    });
    return [for (final r in ranked) r.$1];
  }

  // ---- content ------------------------------------------------------------

  /// Everything whose TEXT contains [query]: a module's description and its
  /// page's text blocks, an object's note and field values, an event's
  /// story, a chapter, a chat's messages, a dialogue's description, and the
  /// text blocks of element pages. One hit per page, first match's snippet.
  Future<List<SearchHit>> content(String query, {int? nexusId}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final fts = q.runes.length >= 3 && await _ftsReady();
    final rows = fts ? await _ftsRows(q, nexusId) : await _likeRows(q, nexusId);
    final seen = <String>{};
    final out = <SearchHit>[];
    for (final r in rows) {
      final key = r['key'] as String;
      if (!seen.add(key)) continue;
      out.add(SearchHit(
        key: key,
        title: r['title'] as String? ?? '',
        nexusId: r['nexus_id'] as int,
        moduleId: r['module_id'] as int,
        moduleName: r['module_name'] as String? ?? '',
        itemKind: r['item_kind'] as String,
        snippet: snippetOf(r['body'] as String? ?? '', q),
      ));
      if (out.length >= _limit) break;
    }
    return out;
  }

  /// Whether the content search is running on the FTS index — false until a
  /// query of three characters or more has needed it.
  bool get usingFts => _ftsState == true;

  bool? _ftsState;
  Future<bool>? _ftsBuild;

  Future<bool> _ftsReady() {
    if (useFts == false) return Future.value(false);
    return _ftsBuild ??= _buildFts();
  }

  Future<bool> _buildFts() async {
    try {
      await db.execute('DROP TABLE IF EXISTS temp.$_ftsTable');
      await db.execute(
        "CREATE VIRTUAL TABLE temp.$_ftsTable USING fts5("
        "key UNINDEXED, title UNINDEXED, item_kind UNINDEXED, module_id UNINDEXED, "
        "module_name UNINDEXED, nexus_id UNINDEXED, body, tokenize='trigram')",
      );
      await db.execute(
        'INSERT INTO temp.$_ftsTable (key, title, item_kind, module_id, module_name, nexus_id, body) '
        'SELECT key, title, item_kind, module_id, module_name, nexus_id, body FROM ($_docsSql) '
        "WHERE body IS NOT NULL AND body <> ''",
      );
    } catch (_) {
      // No fts5, a SQLite older than trigram, or a web build whose SQLite
      // reports either its own way: the LIKE scan it is. Every platform's
      // error type is caught, because this is a probe, not a failure.
      _ftsState = false;
      return false;
    }
    _ftsState = true;
    return true;
  }

  Future<List<Map<String, Object?>>> _ftsRows(String q, int? nexusId) {
    // A phrase, so what was typed is matched as one run of characters — the
    // trigram tokenizer then finds it anywhere, like LIKE does.
    final phrase = '"${q.replaceAll('"', '""')}"';
    return db.rawQuery(
      'SELECT key, title, item_kind, module_id, module_name, nexus_id, body '
      'FROM temp.$_ftsTable WHERE $_ftsTable MATCH ?'
      '${nexusId == null ? '' : ' AND nexus_id = ?'} LIMIT 400',
      [phrase, ?nexusId],
    );
  }

  Future<List<Map<String, Object?>>> _likeRows(String q, int? nexusId) {
    final pattern = '%${q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    return db.rawQuery(
      "SELECT * FROM ($_docsSql) WHERE body LIKE ? ESCAPE '\\'"
      '${nexusId == null ? '' : ' AND nexus_id = ?'} LIMIT 400',
      [pattern, ?nexusId],
    );
  }

  /// Every searchable text as (key, title, item_kind, module_id, module_name,
  /// nexus_id, body) — one row per text, so a page with several texts has
  /// several rows. The same sources the desktop indexes (db/wiki-sources.js).
  static const _docsSql = '''
    SELECT 'module_' || m.id AS key, m.name AS title, 'module' AS item_kind,
           m.id AS module_id, m.name AS module_name, m.nexus_ref AS nexus_id,
           m.description AS body
      FROM module m
    UNION ALL
    SELECT COALESCE(b.item_key, 'module_' || m.id),
           CASE substr(b.item_key, 1, 5)
             WHEN 'cobj_' THEN (SELECT name FROM classifier_object WHERE id = CAST(substr(b.item_key, 6) AS INTEGER))
             WHEN 'tlev_' THEN (SELECT event_name FROM timeline_event WHERE id = CAST(substr(b.item_key, 6) AS INTEGER))
             WHEN 'bchp_' THEN (SELECT name FROM book_chapter WHERE id = CAST(substr(b.item_key, 6) AS INTEGER))
             WHEN 'chss_' THEN (SELECT name FROM chat_session WHERE id = CAST(substr(b.item_key, 6) AS INTEGER))
             WHEN 'sdlg_' THEN (SELECT name FROM story_dialogue WHERE id = CAST(substr(b.item_key, 6) AS INTEGER))
             ELSE m.name
           END,
           CASE substr(b.item_key, 1, 5)
             WHEN 'cobj_' THEN 'object' WHEN 'tlev_' THEN 'event' WHEN 'bchp_' THEN 'chapter'
             WHEN 'chss_' THEN 'chat' WHEN 'sdlg_' THEN 'dialogue'
             ELSE 'module'
           END,
           m.id, m.name, m.nexus_ref,
           CASE WHEN b.prop_name IS NULL THEN b.content ELSE b.prop_name || ': ' || COALESCE(b.content, '') END
      FROM page_block b JOIN module m ON b.module_ref = m.id
     WHERE b.block_type IN ('text', 'heading', 'property') AND b.item_key IS NOT '*'
    UNION ALL
    SELECT 'cobj_' || co.id, co.name, 'object', m.id, m.name, m.nexus_ref, co.note
      FROM classifier_object co JOIN module m ON co.module_ref = m.id
    UNION ALL
    SELECT 'cobj_' || co.id, co.name, 'object', m.id, m.name, m.nexus_ref, ca.attribute_value
      FROM classifier_attribute ca
      JOIN classifier_object co ON ca.object_ref = co.id
      JOIN module m ON co.module_ref = m.id
    UNION ALL
    SELECT 'tlev_' || te.id, COALESCE(te.event_name, ''), 'event', m.id, m.name, m.nexus_ref, te.story
      FROM timeline_event te
      JOIN timeline t ON te.timeline_id = t.id
      JOIN module m ON t.module_ref = m.id
    UNION ALL
    SELECT 'bchp_' || bc.id, bc.name, 'chapter', m.id, m.name, m.nexus_ref,
           COALESCE(bc.synopsis || char(10), '') || COALESCE(bc.chapter_content, '')
      FROM book_chapter bc JOIN module m ON bc.module_ref = m.id
    UNION ALL
    SELECT 'chss_' || cs.id, cs.name, 'chat', m.id, m.name, m.nexus_ref, cm.message
      FROM chat_message cm
      JOIN chat_session cs ON cm.session_ref = cs.id
      JOIN module m ON cs.module_ref = m.id
    UNION ALL
    SELECT 'sdlg_' || sd.id, sd.name, 'dialogue', m.id, m.name, m.nexus_ref, sd.description
      FROM story_dialogue sd JOIN module m ON sd.module_ref = m.id
  ''';

  /// About [radius] characters either side of the first match, on one line.
  static String snippetOf(String body, String query, {int radius = 40}) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final at = flat.toLowerCase().indexOf(query.trim().toLowerCase());
    if (at < 0) return flat.length <= radius * 2 ? flat : '${flat.substring(0, radius * 2)}…';
    final start = at - radius < 0 ? 0 : at - radius;
    final end = at + query.trim().length + radius > flat.length ? flat.length : at + query.trim().length + radius;
    return '${start > 0 ? '…' : ''}${flat.substring(start, end)}${end < flat.length ? '…' : ''}';
  }

  // ---- helpers ------------------------------------------------------------

  Future<List<int>> _nexusIds(int? only) async {
    if (only != null) return [only];
    final rows = await db.rawQuery('SELECT id FROM nexus ORDER BY name COLLATE NOCASE');
    return [for (final r in rows) r['id'] as int];
  }

  static SearchHit _hitOf(IndexedItem it, int nexusId) => SearchHit(
        key: it.key,
        title: it.name,
        nexusId: nexusId,
        moduleId: it.moduleId,
        moduleName: it.moduleName,
        itemKind: it.itemKind,
      );
}

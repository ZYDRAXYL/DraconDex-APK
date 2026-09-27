import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'bundle_service.dart';

/// Page templates on the phone — the port of EXE db/page-template.js (APP
/// docs/TEMPLATES.md §3). `assets/templates/pages.json` is VENDORED from
/// DraconDex-SDB; `node tools/sdb-vendor.mjs` replaces it.
///
/// A template is a module's page (and, for a kind with elements, the page
/// its elements share) plus, for a Classifier, the fields it starts with.
/// Blocks are `{ type?, component?, config?, content?, children?, borrow? }`
/// — `columns` holds its children as columns of blocks. A `borrow` names a
/// module inside a bundle (resolved by the caller's refs), or is `true` in
/// a standalone template — unbound, so it is left out and counted.
///
/// Applying replaces a page in one transaction and hands back the rows it
/// removed, so Undo puts the old page back exactly ([restore]).
class PageTemplate {
  final String id, kind, name, description;
  final bool isDefault;
  final List<String> forTypes;
  final List page, itemPage;
  final Map<String, dynamic>? preset;
  const PageTemplate(this.id, this.kind, this.name, this.description, this.isDefault, this.forTypes, this.page, this.itemPage, this.preset);

  factory PageTemplate.fromJson(Map<String, dynamic> t) => PageTemplate(
        '${t['id']}',
        '${t['kind']}',
        '${t['name'] ?? t['id']}',
        '${t['description'] ?? ''}',
        t['default'] == true,
        [for (final f in (t['for'] as List?) ?? const []) '$f'],
        (t['page'] as List?) ?? const [],
        (t['itemPage'] as List?) ?? const [],
        t['preset'] is Map ? (t['preset'] as Map).cast<String, dynamic>() : null,
      );
}

/// A page's rows as they were, for Undo.
typedef OldPages = Map<String, List<Map<String, Object?>>>;

class ApplyResult {
  final OldPages old;
  final int dropped, fields;
  const ApplyResult(this.old, this.dropped, this.fields);
}

class _Row {
  final String type;
  final String? component, content, sourceKey;
  Map<String, Object?>? config;
  List<List<_Row>> children = const [];
  _Row(this.type, this.component, this.config, this.content, this.sourceKey);
}

class PageTemplateService {
  static Map<String, dynamic>? _catalog;

  /// The vendored catalog; [raw] replaces it (tests).
  static Future<Map<String, dynamic>> catalog({String? raw}) async {
    if (raw != null) return _catalog = jsonDecode(raw) as Map<String, dynamic>;
    return _catalog ??= jsonDecode(await rootBundle.loadString('assets/templates/pages.json')) as Map<String, dynamic>;
  }

  /// Every template, names in [locale]; a kind's ★ first.
  static Future<List<PageTemplate>> templates(String locale, {String? kind}) async {
    final c = await catalog();
    final strings = (c['strings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = [
      for (final t in (c['templates'] as List? ?? const []))
        if (kind == null || (t as Map)['kind'] == kind)
          PageTemplate.fromJson((BundleService.resolveStrings(t, strings, locale) as Map).cast<String, dynamic>()),
    ];
    out.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    return out;
  }

  /// Component ids the catalog lists, with their `since` (exe / planned).
  static Future<Map<String, String>> components() async =>
      {for (final c in ((await catalog())['components'] as List? ?? const [])) '${c['id']}': '${c['since'] ?? ''}'};

  /// A kind's ★ — for a Classifier, the ★ of its catType (TEMPLATES.md §3.2).
  static Future<PageTemplate?> defaultFor(String kind, String locale, {String? catType}) async {
    final ts = (await templates(locale, kind: kind)).where((t) => t.isDefault).toList();
    if (kind != 'classifier') return ts.firstOrNull;
    return ts.where((t) => t.forTypes.contains(catType ?? 'object')).firstOrNull ?? ts.where((t) => t.forTypes.contains('object')).firstOrNull;
  }

  /// A field's key rides in its options JSON (no schema change).
  static String? optionsWithKey(Object? options, String? key) {
    if (key == null || key.isEmpty) return options is String ? options : (options == null ? null : jsonEncode(options));
    Map<String, dynamic> o = {};
    if (options is String) {
      try {
        final v = jsonDecode(options.isEmpty ? '{}' : options);
        if (v is Map) o = v.cast<String, dynamic>();
      } catch (_) {}
    } else if (options is Map) {
      o = {...options.cast<String, dynamic>()};
    }
    return jsonEncode({...o, 'key': key});
  }

  /// Template blocks → a tree of rows to insert. [refs]: bundle ref → module id.
  static (List<_Row>, int) _layoutRows(List blocks, Map<String, int>? refs) {
    var dropped = 0;
    List<_Row> walk(List list) {
      final out = <_Row>[];
      for (final b in list) {
        if (b is! Map) continue;
        final type = '${b['type'] ?? 'component'}';
        String? sourceKey;
        if (b.containsKey('borrow')) {
          final id = b['borrow'] is String && refs != null ? refs[b['borrow']] : null;
          if (id == null) {
            dropped++;
            continue;
          }
          sourceKey = 'module_$id';
        }
        final row = _Row(type, b['component'] as String?, b['config'] is Map ? {...(b['config'] as Map).cast<String, Object?>()} : null,
            b['content'] as String?, sourceKey);
        if (type == 'columns' || b['children'] is List) {
          final cols = [for (final col in (b['children'] as List? ?? const [])) walk(col is List ? col : const [])];
          row.children = cols;
          if (type == 'columns') row.config = {...?row.config, 'n': cols.length.clamp(2, 3)};
        }
        out.add(row);
      }
      return out;
    }

    final rows = walk(blocks);
    return (rows, dropped);
  }

  static String _where(String? itemKey) => itemKey == null ? 'item_key IS NULL' : 'item_key=?';
  static List<Object?> _args(int moduleId, String? itemKey) => itemKey == null ? [moduleId] : [moduleId, itemKey];

  static Future<void> _insert(DatabaseExecutor d, int moduleId, String? itemKey, List<_Row> rows, [int? parentId, int? col]) async {
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final config = col == null ? r.config : {...?r.config, 'col': col};
      final id = await d.insert('page_block', {
        'module_ref': moduleId,
        'item_key': itemKey,
        'parent_id': parentId,
        'block_type': r.type,
        'component': r.component,
        'source_key': r.sourceKey,
        'config': config == null || config.isEmpty ? null : jsonEncode(config),
        'content': r.content,
        'block_order': i,
      });
      for (var c = 0; c < r.children.length; c++) {
        await _insert(d, moduleId, itemKey, r.children[c], id, c);
      }
    }
  }

  /// Replace one page (null = the module's, '*' = its elements') — its
  /// stacked blocks only; properties are the page's data, not its layout.
  static Future<List<Map<String, Object?>>> _replace(DatabaseExecutor d, int moduleId, String? itemKey, List<_Row> rows) async {
    final old = await d.rawQuery(
        "SELECT * FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND block_type<>'property'", _args(moduleId, itemKey));
    await d.rawDelete("DELETE FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND block_type<>'property'", _args(moduleId, itemKey));
    await _insert(d, moduleId, itemKey, rows);
    await d.rawInsert("INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,'1')",
        [moduleId, itemKey == null ? 'pageInit' : 'itemPageInit']);
    return old;
  }

  /// One page from template [blocks] (a bundle's module.page), inside the
  /// caller's transaction. [refs]: bundle ref → module id, for borrows.
  static Future<int> fillPage(DatabaseExecutor d, int moduleId, String? itemKey, List blocks, Map<String, int> refs) async {
    final (rows, dropped) = _layoutRows(blocks, refs);
    await _replace(d, moduleId, itemKey, rows);
    return dropped;
  }

  /// A template by id, names untranslated — what a bundle names.
  static Future<PageTemplate?> byId(String id) async =>
      (await templates('en')).where((t) => t.id == id).firstOrNull;

  /// A template's preset fields, onto a Classifier that has none yet —
  /// never onto one the user already shaped.
  static Future<int> _presetFields(DatabaseExecutor d, int moduleId, Map<String, dynamic>? preset) async {
    final fields = (preset?['fields'] as List?) ?? const [];
    if (fields.isEmpty) return 0;
    final have = (await d.rawQuery('SELECT COUNT(*) AS n FROM classifier_template WHERE module_ref=? AND object_ref IS NULL', [moduleId])).first['n'] as int;
    if (have > 0) return 0;
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i] as Map;
      final name = '${f['name'] ?? f['key']}';
      await d.insert('classifier_template', {
        'module_ref': moduleId,
        'description': name.length > 200 ? name.substring(0, 200) : name,
        'attribute_type': f['type'] ?? 'text',
        'levelable': f['levelable'] == true ? 1 : 0,
        'has_condition': f['hasCondition'] == true ? 1 : 0,
        'display_order': i,
        'options': optionsWithKey(f['options'], f['key'] as String?),
      });
    }
    return fields.length;
  }

  /// Apply [tpl] to a module. [fields]: add the template's preset fields
  /// when the module has none.
  static Future<ApplyResult> apply(Database db, int moduleId, PageTemplate tpl, {Map<String, int>? refs, bool fields = true}) async {
    final m = await db.rawQuery('SELECT kind FROM module WHERE id=?', [moduleId]);
    if (m.isEmpty) throw StateError('module not found');
    return db.transaction((d) async {
      final old = <String, List<Map<String, Object?>>>{};
      var dropped = 0, added = 0;
      if (m.first['kind'] == 'classifier' && fields) added = await _presetFields(d, moduleId, tpl.preset);
      if (tpl.page.isNotEmpty) {
        final (rows, n) = _layoutRows(tpl.page, refs);
        old['page'] = await _replace(d, moduleId, null, rows);
        dropped += n;
      }
      if (tpl.itemPage.isNotEmpty) {
        final (rows, n) = _layoutRows(tpl.itemPage, refs);
        old['itemPage'] = await _replace(d, moduleId, '*', rows);
        dropped += n;
      }
      return ApplyResult(old, dropped, added);
    });
  }

  /// Undo of [apply]: the pages it touched go back to their old rows.
  static Future<void> restore(Database db, int moduleId, OldPages old) => db.transaction((d) async {
        for (final e in old.entries) {
          final itemKey = e.key == 'itemPage' ? '*' : null;
          await d.rawDelete("DELETE FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND block_type<>'property'", _args(moduleId, itemKey));
          for (final r in e.value) {
            await d.insert('page_block', r, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });

  /// A page as template blocks — the desktop's "Save this page as
  /// template" and a bundle's capture. [borrowRef]: a borrowed block's
  /// source_key → the ref to keep it bound, or null to leave it out.
  static Future<List<Map<String, Object?>>> capturePage(DatabaseExecutor d, int moduleId, String? itemKey,
      {Object? Function(String sourceKey)? borrowRef}) async {
    final rows = await d.rawQuery(
        "SELECT * FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND block_type<>'property' ORDER BY block_order, id", _args(moduleId, itemKey));
    final kids = <int, List<Map<String, Object?>>>{};
    for (final r in rows) {
      if (r['parent_id'] != null) (kids[r['parent_id'] as int] ??= []).add(r);
    }
    int colOf(Map<String, Object?> k) {
      try {
        return (((jsonDecode('${k['config'] ?? '{}'}') as Map)['col'] as num?)?.toInt() ?? 0).clamp(0, 11);
      } catch (_) {
        return 0;
      }
    }

    Map<String, Object?>? block(Map<String, Object?> r) {
      Map<String, Object?>? config;
      try {
        final v = r['config'] == null ? null : jsonDecode('${r['config']}');
        if (v is Map) config = {...v.cast<String, Object?>()}..remove('col');
      } catch (_) {}
      final b = <String, Object?>{};
      if (r['block_type'] != 'component') b['type'] = r['block_type'];
      if (r['component'] != null) b['component'] = r['component'];
      if (r['source_key'] != null) {
        final to = borrowRef == null ? true : borrowRef('${r['source_key']}');
        if (to == null) return null;
        b['borrow'] = to;
      }
      if (r['content'] != null) b['content'] = r['content'];
      // columns, and a container component (tabs, toggle): children by slot
      final mine = kids[r['id'] as int] ?? const [];
      if (r['block_type'] == 'columns' || mine.isNotEmpty) {
        final n = r['block_type'] == 'columns'
            ? ((config?['n'] as num?)?.toInt() ?? 2).clamp(2, 3)
            : mine.fold<int>(1, (m, k) => colOf(k) + 1 > m ? colOf(k) + 1 : m);
        final cols = List.generate(n, (_) => <Map<String, Object?>>[]);
        for (final k in mine) {
          final kb = block(k);
          if (kb != null) cols[colOf(k).clamp(0, n - 1)].add(kb);
        }
        b['children'] = cols;
        if (r['block_type'] == 'columns') config?.remove('n');
      }
      if (config != null && config.isNotEmpty) b['config'] = config;
      return b;
    }

    return [for (final r in rows) if (r['parent_id'] == null) ?block(r)];
  }
}

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'page_template_service.dart';

/// A user's own page templates on the phone — the port of EXE db/preset.js
/// (APP docs/TEMPLATES.md §3.3, V5.md §10.8). A preset is kept in the
/// vault's `module_preset` table, so it travels with the vault and syncs in
/// the snapshot's `modulePresets`; a row saved on either app reads the same
/// on the other.
///
/// spec (JSON), every field optional:
///   icon, color, iconColor   colour CODES, resolved to this vault's ids on apply
///   description
///   catType                  Classifier only: object | character | element
///   ui                       view settings from [uiKeys]
///   fields                   Classifier only: [{ name, type, key?, options?, levelable, hasCondition }]
///   tables                   Diviner only: [{ name, dice, mode, entries: [{ text, weight, lo, hi, table }] }]
///   page, itemPage           template blocks — a preset IS a user's page template
///
/// Settings that name other rows by id (filterDef, managerPicks, …) are
/// never captured: they would point at the wrong thing in a new module.
class PresetService {
  static const uiKeys = ['activeView', 'view', 'boardGroupBy', 'calendarConfig'];
  static const _catTypes = {'object', 'character', 'element'};
  static const _fieldTypes = {'text', 'textarea', 'date', 'number', 'select', 'multi', 'checkbox', 'url', 'relation', 'formula'};
  static const _maxFields = 40, _maxTables = 20, _maxEntries = 200;
  static const _maxBlocks = 60, _maxBlockJson = 200000;

  /// Template blocks as stored: plain JSON, bounded (EXE cleanBlocks).
  static List<Map<String, Object?>>? cleanBlocks(Object? v) {
    if (v is! List || v.isEmpty) return null;
    List<Map<String, Object?>> walk(Object? list, int depth) => [
          for (final b in (list is List ? list : const []).take(_maxBlocks))
            if (b is Map)
              {
                if (b['type'] is String) 'type': _cut(b['type'] as String, 20),
                if (b['component'] is String) 'component': _cut(b['component'] as String, 60),
                if (b['config'] is Map) 'config': b['config'],
                if (b['content'] is String) 'content': _cut(b['content'] as String, 20000),
                if (b['borrow'] == true || b['borrow'] is String) 'borrow': b['borrow'],
                if (b['children'] is List && depth < 2)
                  'children': [for (final c in (b['children'] as List).take(3)) walk(c, depth + 1)],
              },
        ];
    final out = walk(v, 0);
    return jsonEncode(out).length <= _maxBlockJson ? out : null;
  }

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
  static String? _str(Object? v, [int n = 200]) => v is String && v.isNotEmpty ? _cut(v, n) : null;
  static int? _int(Object? v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}');
    return n == null || !n.isFinite ? null : n.truncate();
  }

  /// Anything that did not come from [capture] — a hand-edited row, one
  /// from an older app — narrowed to the shape above (EXE cleanSpec).
  static Map<String, Object?> cleanSpec(Object? raw) {
    Object? s = raw;
    if (s is String) {
      try {
        s = jsonDecode(s);
      } catch (_) {
        s = null;
      }
    }
    if (s is! Map) return {};
    final out = <String, Object?>{};
    if (_str(s['icon']) case final v?) out['icon'] = v;
    for (final k in ['color', 'iconColor']) {
      if (_str(s[k], 16) case final v?) out[k] = v;
    }
    if (_str(s['description'], 4000) case final v?) out['description'] = v;
    if (_catTypes.contains(s['catType'])) out['catType'] = s['catType'];
    if (s['ui'] is Map) {
      final ui = {for (final k in uiKeys) if ((s['ui'] as Map)[k] is String) k: _cut((s['ui'] as Map)[k] as String, 4000)};
      if (ui.isNotEmpty) out['ui'] = ui;
    }
    if (s['fields'] is List) {
      out['fields'] = [
        for (final f in (s['fields'] as List).take(_maxFields))
          if (f is Map && _str(f['name']) != null)
            {
              'name': _str(f['name']),
              'type': _fieldTypes.contains(f['type']) ? f['type'] : 'text',
              if (f['key'] is String && RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(f['key'] as String)) 'key': f['key'],
              'options': ?_str(f['options'], 4000),
              'levelable': f['levelable'] == true || f['levelable'] == 1,
              'hasCondition': f['hasCondition'] == true || f['hasCondition'] == 1,
            },
      ];
    }
    if (s['tables'] is List) {
      final tabs = (s['tables'] as List).take(_maxTables).toList();
      out['tables'] = [
        for (final tb in tabs)
          if (tb is Map && _str(tb['name']) != null)
            {
              'name': _str(tb['name']),
              'dice': _str(tb['dice'], 20),
              'mode': tb['mode'] == 'join' ? 'join' : 'pick',
              'entries': [
                for (final e in (tb['entries'] is List ? tb['entries'] as List : const []).take(_maxEntries))
                  {
                    'text': (e is Map ? _str(e['text'], 1000) : null) ?? '',
                    'weight': e is Map ? ((_int(e['weight']) ?? 1) < 0 ? 0 : (_int(e['weight']) ?? 1)) : 1,
                    'lo': e is Map ? _int(e['lo']) : null,
                    'hi': e is Map ? _int(e['hi']) : null,
                    'table': e is Map && e['table'] is int && (e['table'] as int) >= 0 && (e['table'] as int) < tabs.length ? e['table'] : null,
                  },
              ],
            },
      ];
    }
    for (final k in ['page', 'itemPage']) {
      if (cleanBlocks(s[k]) case final b?) out[k] = b;
    }
    return out;
  }

  static Future<String?> _colorCode(DatabaseExecutor d, Object? id) async {
    if (id == null) return null;
    final r = await d.rawQuery('SELECT color_code FROM use_color WHERE id=?', [id]);
    return r.isEmpty ? null : r.first['color_code'] as String?;
  }

  /// What a module is shaped like, as a preset (EXE capturePreset).
  static Future<(String, Map<String, Object?>)> capture(DatabaseExecutor d, int moduleId) async {
    final rows = await d.rawQuery('SELECT id, kind, icon, color, icon_color, description, cat_type FROM module WHERE id=?', [moduleId]);
    if (rows.isEmpty) throw StateError('module not found');
    final m = rows.first;
    final kind = '${m['kind']}';
    final ui = await d.rawQuery('SELECT ui_key, ui_value FROM module_ui WHERE module_ref=?', [moduleId]);
    final spec = <String, Object?>{
      'icon': m['icon'],
      'color': await _colorCode(d, m['color']),
      'iconColor': await _colorCode(d, m['icon_color']),
      'description': m['description'],
      'catType': kind == 'classifier' ? m['cat_type'] : null,
      'ui': {for (final r in ui) if (uiKeys.contains(r['ui_key'])) '${r['ui_key']}': r['ui_value']},
    };
    if (kind == 'classifier') {
      // shared fields only: a private one belongs to one element, not to the shape
      final fs = await d.rawQuery('''
        SELECT description AS name, attribute_type AS type, options, levelable, has_condition AS hasCondition
        FROM classifier_template WHERE module_ref=? AND object_ref IS NULL ORDER BY display_order, id''', [moduleId]);
      spec['fields'] = [
        for (final f in fs)
          {
            ...f,
            'key': ?_keyOf(f['options']),
          },
      ];
    }
    if (kind == 'diviner') {
      // links between this module's own tables become indexes; any other goes
      final tabs = await d.rawQuery('SELECT id, name, dice, mode FROM diviner_table WHERE module_ref=? ORDER BY display_order, id', [moduleId]);
      final idx = {for (final (i, tb) in tabs.indexed) 'divt_${tb['id']}': i};
      spec['tables'] = [
        for (final tb in tabs)
          {
            'name': tb['name'],
            'dice': tb['dice'],
            'mode': tb['mode'],
            'entries': [
              for (final e in await d.rawQuery(
                  'SELECT entry_text, weight, range_lo, range_hi, linker_key FROM diviner_entry WHERE table_ref=? ORDER BY display_order, id', [tb['id']]))
                {'text': e['entry_text'] ?? '', 'weight': e['weight'], 'lo': e['range_lo'], 'hi': e['range_hi'], 'table': idx[e['linker_key']]},
            ],
          },
      ];
    }
    final page = await PageTemplateService.capturePage(d, moduleId, null);
    final itemPage = await PageTemplateService.capturePage(d, moduleId, '*');
    if (page.isNotEmpty) spec['page'] = page;
    if (itemPage.isNotEmpty) spec['itemPage'] = itemPage;
    return (kind, cleanSpec(spec));
  }

  static String? _keyOf(Object? options) {
    try {
      final o = jsonDecode('${options ?? '{}'}');
      return o is Map && o['key'] is String ? o['key'] as String : null;
    } catch (_) {
      return null;
    }
  }

  /// Save [moduleId]'s shape as [name]. The same name for the same kind
  /// replaces — saving twice is an update, not a duplicate.
  static Future<String> save(Database db, int nexusId, int moduleId, String name) async {
    final n = _cut(name.trim(), 120);
    if (n.isEmpty) throw ArgumentError('name required');
    final (kind, spec) = await capture(db, moduleId);
    await db.rawInsert('''
      INSERT INTO module_preset (nexus_ref, kind, name, spec) VALUES (?,?,?,?)
      ON CONFLICT(nexus_ref, kind, name) DO UPDATE SET spec=excluded.spec, update_at=datetime('now')''', [nexusId, kind, n, jsonEncode(spec)]);
    return kind;
  }

  /// This vault's presets of [kind] (every kind when null) — never the
  /// user's Artisan bundles, which share the table under kind 'bundle'.
  static Future<List<({int id, String kind, String name, Map<String, Object?> spec})>> list(DatabaseExecutor d, int nexusId, {String? kind}) async {
    final rows = await d.rawQuery(
        "SELECT id, kind, name, spec FROM module_preset WHERE nexus_ref=? AND kind<>'bundle' AND (? IS NULL OR kind=?) ORDER BY kind, name COLLATE NOCASE",
        [nexusId, kind, kind]);
    return [for (final r in rows) (id: r['id'] as int, kind: '${r['kind']}', name: '${r['name']}', spec: cleanSpec(r['spec']))];
  }

  static Future<int> delete(DatabaseExecutor d, int id) => d.rawDelete('DELETE FROM module_preset WHERE id=?', [id]);

  /// The user's templates for [kind] that carry a page, as page templates
  /// ("Mine" in the gallery; EXE hub/page-templates.js).
  static Future<List<PageTemplate>> mine(DatabaseExecutor d, int nexusId, String kind) async => [
        for (final p in await list(d, nexusId, kind: kind))
          if (p.spec['page'] != null)
            PageTemplate('u:${p.id}', kind, p.name, '', false, const [], p.spec['page'] as List, (p.spec['itemPage'] as List?) ?? const [], p.spec),
      ];
}

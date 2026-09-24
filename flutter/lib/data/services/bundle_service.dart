import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'wiki_service.dart';

/// Bundles — a whole project in one step (V5.md §11.7), the port of EXE
/// db/bundle.js createBundle: a Collector named after it, the modules inside
/// it, and a Manager that selects the Collector, whose page is laid out as
/// the project page. Built in ONE transaction, so a failure leaves nothing
/// half-made. The same spec shape serves the genre bundles and the guide
/// (vendored from DraconDex-SDB templates/) and a CSV import (folder: false).
class BundleService {
  static const maxModules = 60;
  static const kinds = {
    'manager', 'inspector', 'classifier', 'locator', 'chronicler', 'wanderer', 'narrator', //
    'author', 'scribe', 'drafter', 'exhibitor', 'sketcher', 'designer', 'diviner',
  };

  /// Kinds whose view reads well on the project page (EXE PROJECT_VIEWS).
  static const projectViews = {
    'classifier', 'chronicler', 'author', 'narrator', 'scribe', 'diviner', 'locator', //
    'sketcher', 'designer', 'exhibitor', 'inspector', 'drafter',
  };
  static const projectMaxViews = 8;

  static String _s(Object? v, [int n = 4000]) {
    final s = v is String ? v : (v == null ? '' : '$v');
    return s.length > n ? s.substring(0, n) : s;
  }

  static List _a(Object? v) => v is List ? v : const [];

  /// `{t: key, suffix}` → the string in [locale], else English, else the key
  /// (SDB templates/README.md). Plain strings pass through.
  static Object? resolveStrings(Object? v, Map<String, dynamic> strings, String locale) {
    if (v is Map) {
      if (v['t'] is String && v.keys.every((k) => k == 't' || k == 'suffix')) {
        final e = strings[v['t']];
        final base = e is Map ? (e[locale] ?? e['en'] ?? v['t']) : v['t'];
        return '$base${v['suffix'] ?? ''}';
      }
      return <String, dynamic>{for (final e in v.entries) '${e.key}': resolveStrings(e.value, strings, locale)};
    }
    if (v is List) return <dynamic>[for (final x in v) resolveStrings(x, strings, locale)];
    return v;
  }

  /// The genre bundles, resolved in [locale], in the picker's order.
  static Future<List<Map<String, dynamic>>> loadBundles(String locale) async {
    final d = jsonDecode(await rootBundle.loadString('assets/templates/bundles.json')) as Map<String, dynamic>;
    final strings = d['strings'] as Map<String, dynamic>;
    final out = [
      for (final b in d['bundles'] as List) resolveStrings(b, strings, locale) as Map<String, dynamic>,
    ]..sort((a, b) => (a['order'] as num? ?? 0).compareTo(b['order'] as num? ?? 0));
    return out;
  }

  /// The in-app guide's spec in [locale], falling back to English.
  static Future<Map<String, dynamic>> loadGuide(String locale) async {
    String raw;
    try {
      raw = await rootBundle.loadString('assets/templates/guide/$locale.json');
    } catch (_) {
      raw = await rootBundle.loadString('assets/templates/guide/en.json');
    }
    return (jsonDecode(raw) as Map<String, dynamic>)['spec'] as Map<String, dynamic>;
  }

  static Future<int?> _colorId(DatabaseExecutor d, Object? code) async {
    if (code is! String || !RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(code)) return null;
    final hit = await d.rawQuery('SELECT id FROM use_color WHERE color_code=?', [code]);
    return hit.isNotEmpty ? hit.first['id'] as int : d.insert('use_color', {'color_code': code});
  }

  static Future<int> _module(DatabaseExecutor d, int nexusId, int? parent, String name, String kind,
      {Object? icon, int? color, String? catType}) async {
    final o = await d.rawQuery(
        'SELECT COALESCE(MAX(display_order),-1)+1 AS o FROM module WHERE nexus_ref=? AND parent_id IS ?', [nexusId, parent]);
    return d.insert('module', {
      'nexus_ref': nexusId,
      'parent_id': parent,
      'name': name,
      'kind': kind,
      'icon': icon is String ? icon : null,
      'color': color,
      'icon_color': color,
      'display_order': o.first['o'],
      'cat_type': ?catType,
    });
  }

  static Future<void> _ui(DatabaseExecutor d, int m, String k, String v) => d.execute(
      'INSERT INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,?) '
      'ON CONFLICT(module_ref, ui_key) DO UPDATE SET ui_value=excluded.ui_value',
      [m, k, v]);

  static Future<int> _date(DatabaseExecutor d, int day, int month, int years) async {
    final hit = await d.rawQuery(
        'SELECT id FROM timeline_date WHERE day=? AND month=? AND years=? AND hour=0 AND minute=0', [day, month, years]);
    if (hit.isNotEmpty) return hit.first['id'] as int;
    return d.insert('timeline_date', {'day': day, 'month': month, 'years': years, 'hour': 0, 'minute': 0});
  }

  /// A bundle's Manager page is the project page: its selection, then the
  /// bundle's modules as borrowed views (EXE projectPage).
  static Future<void> _projectPage(DatabaseExecutor d, int managerId, List<int> ids, List<Map> mods) async {
    var order = 0, shown = 0;
    Future<void> add(String component, String? source, String? config) => d.insert('page_block', {
          'module_ref': managerId,
          'item_key': null,
          'block_type': 'component',
          'component': component,
          'source_key': source,
          'config': config,
          'block_order': order++,
        });
    await add('core.properties', null, null);
    await add('manager.view', null, jsonEncode({'preset': 'cards'}));
    for (var i = 0; i < ids.length; i++) {
      if (!projectViews.contains(mods[i]['kind']) || shown >= projectMaxViews) continue;
      await add('${mods[i]['kind']}.view', 'module_${ids[i]}', null);
      shown++;
    }
    await add('core.related', null, null);
    await d.rawInsert("INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?, 'pageInit', '1')", [managerId]);
  }

  /// Builds [spec] under [parentId]. Returns (folder, manager, module ids);
  /// throws [ArgumentError] without a name.
  static Future<({int? folderId, int? managerId, List<int> moduleIds})> create(
      Database db, int nexusId, int? parentId, Map<String, dynamic> spec) async {
    final name = _s(spec['name'], 200).trim();
    if (name.isEmpty) throw ArgumentError('name_required');
    final mods = [
      for (final m in _a(spec['modules']))
        if (m is Map && kinds.contains(m['kind']) && _s(m['name'], 200).trim().isNotEmpty) m,
    ].take(maxModules).toList();
    final out = await db.transaction((d) async {
      final col = await _colorId(d, spec['color']);
      final bare = spec['folder'] == false;
      final folderId = bare ? parentId : await _module(d, nexusId, parentId, name, 'collector', icon: spec['icon'], color: col);
      final created = <int>[];
      final modByRef = <String, int>{};
      final objByRef = <String, int>{};
      final pendingFieldRel = <(int, String, Map<String, dynamic>)>[];
      final pendingLinks = <(int, int, List)>[];
      final pendingSelects = <(int, List)>[];
      for (final m in mods) {
        final kind = m['kind'] as String;
        final id = await _module(d, nexusId, folderId, _s(m['name'], 200).trim(), kind,
            icon: m['icon'],
            color: col,
            catType: kind == 'classifier' ? (const ['object', 'character', 'element'].contains(m['catType']) ? m['catType'] as String : 'object') : null);
        created.add(id);
        if (m['ref'] is String) modByRef[m['ref'] as String] = id;
        if (m['description'] != null) {
          await d.rawUpdate('UPDATE module SET description=? WHERE id=?', [_s(m['description'], 20000), id]);
        }
        switch (kind) {
          case 'classifier':
            final tplByName = <String, int>{};
            var fo = 0;
            for (final f in _a(m['fields'])) {
              if (f is! Map) continue;
              final raw = f['options'];
              final opts = <String, dynamic>{
                ...?(raw is String ? jsonDecode(raw) as Map<String, dynamic>? : raw as Map<String, dynamic>?),
                if (f['role'] != null) 'role': f['role'],
              };
              final tid = await d.insert('classifier_template', {
                'module_ref': id,
                'description': _s(f['name'], 200),
                'attribute_type': f['type'] ?? 'text',
                'levelable': f['levelable'] == true ? 1 : 0,
                'has_condition': f['hasCondition'] == true ? 1 : 0,
                'options': opts.isEmpty ? null : jsonEncode(opts),
                'display_order': fo++,
              });
              tplByName[_s(f['name'], 200)] = tid;
              if (f['relTo'] is String) pendingFieldRel.add((tid, f['relTo'] as String, opts));
            }
            var oo = 0;
            for (final ob in _a(m['objects'])) {
              if (ob is! Map) continue;
              final oid = await d.insert('classifier_object', {
                'module_ref': id,
                'name': _s(ob['name'], 200),
                'note': ob['note'] == null ? null : _s(ob['note'], 20000),
                'display_order': oo++,
              });
              if (ob['ref'] is String) objByRef[ob['ref'] as String] = oid;
              for (final e in (ob['values'] as Map? ?? const {}).entries) {
                final tid = tplByName[e.key];
                if (tid == null) continue;
                final v = e.value;
                final val = v is List ? jsonEncode(v) : (v is bool ? (v ? '1' : '0') : _s(v));
                await d.insert('classifier_attribute', {'object_ref': oid, 'template_ref': tid, 'attribute_value': val},
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
              for (final e in (ob['links'] as Map? ?? const {}).entries) {
                final tid = tplByName[e.key];
                if (tid != null) pendingLinks.add((oid, tid, _a(e.value)));
              }
            }
          case 'author':
            final cs = _a(m['chapters']);
            for (var i = 0; i < cs.length; i++) {
              final c = cs[i] as Map;
              await d.insert('book_chapter', {
                'module_ref': id,
                'name': _s(c['name'], 200),
                'chapter_label': '${i + 1}',
                'chapter_content': c['content'] == null ? null : _s(c['content'], 200000),
                'chapter_order': i,
                'synopsis': c['synopsis'] == null ? null : _s(c['synopsis']),
                'status': const ['idea', 'draft', 'revised', 'done'].contains(c['status']) ? c['status'] : null,
              });
            }
          case 'diviner':
            final tables = _a(m['tables']);
            final ids = <int>[];
            for (var i = 0; i < tables.length; i++) {
              final t = tables[i] as Map;
              ids.add(await d.insert('diviner_table', {
                'module_ref': id,
                'name': _s(t['name'], 200),
                'dice': t['dice'],
                'mode': t['mode'] ?? 'pick',
                'display_order': i,
              }));
            }
            for (var i = 0; i < tables.length; i++) {
              final es = _a((tables[i] as Map)['entries']);
              for (var k = 0; k < es.length; k++) {
                final e = es[k] as Map;
                await d.insert('diviner_entry', {
                  'table_ref': ids[i],
                  'weight': e['weight'] ?? 1,
                  'range_lo': e['lo'],
                  'range_hi': e['hi'],
                  'entry_text': e['text'],
                  'linker_key': e['table'] is int && (e['table'] as int) < ids.length ? 'divt_${ids[e['table'] as int]}' : null,
                  'display_order': k,
                });
              }
            }
          case 'chronicler':
            final tl = await d.insert('timeline', {'module_ref': id, 'line_name': _s(m['name'], 200)});
            for (final e in _a(m['events'])) {
              if (e is! Map) continue;
              final dt = [for (final n in _a(e['date'])) (n is num ? n.toInt() : int.tryParse('$n') ?? 0)];
              int at(int i) => i < dt.length && dt[i] != 0 ? dt[i] : 1;
              await d.insert('timeline_event', {
                'timeline_id': tl,
                'event_name': _s(e['name'], 200),
                'start_at': await _date(d, at(2), at(1), at(0)),
                'story': e['story'] == null ? null : _s(e['story']),
              });
            }
          case 'narrator':
            final gs = _a(m['dialogues']);
            int? prev;
            for (var i = 0; i < gs.length; i++) {
              final g = gs[i] as Map;
              final gid = await d.insert('story_dialogue', {
                'module_ref': id,
                'name': _s(g['name'], 200),
                'description': g['description'] == null ? null : _s(g['description']),
                'pos_x': 80 + i * 220,
                'pos_y': 120,
              });
              final talks = _a(g['talks']);
              for (var k = 0; k < talks.length; k++) {
                final tk = talks[k] as Map;
                await d.insert('story_talk', {
                  'dialogue_ref': gid,
                  'speaker': tk['speaker'] == null ? null : _s(tk['speaker'], 200),
                  'talk_sentence': _s(tk['text']),
                  'talk_order': k,
                  'row_type': 'talk',
                });
              }
              if (prev != null) {
                await d.insert('story_edge', {'module_ref': id, 'from_ref': prev, 'to_ref': gid},
                    conflictAlgorithm: ConflictAlgorithm.ignore);
              }
              prev = gid;
            }
          case 'scribe':
            for (final s in _a(m['sessions'])) {
              if (s is! Map) continue;
              final sid = await d.insert('chat_session', {'module_ref': id, 'name': _s(s['name'], 200)});
              for (final msg in _a(s['messages'])) {
                await d.insert('chat_message', {'session_ref': sid, 'message': _s(msg)});
              }
            }
          case 'designer':
            for (final n in _a(m['nodes'])) {
              if (n is! Map) continue;
              await d.insert('design_node', {
                'module_ref': id,
                'shape': _s(n['shape'], 20).isEmpty ? 'box' : _s(n['shape'], 20),
                'x': (n['x'] as num?) ?? 0,
                'y': (n['y'] as num?) ?? 0,
                'node_text': n['text'] == null ? null : _s(n['text']),
              });
            }
          case 'sketcher':
            final ps = _a(m['pages']);
            for (var i = 0; i < ps.length; i++) {
              await d.insert('sketch_page', {'module_ref': id, 'name': _s(ps[i], 200), 'page_order': i});
            }
          case 'exhibitor' || 'manager':
            if (_a(m['selects']).isNotEmpty) pendingSelects.add((id, _a(m['selects'])));
        }
      }
      // A relation field names the module it points into; values point at objects.
      for (final (tid, relTo, o) in pendingFieldRel) {
        final target = modByRef[relTo];
        if (target != null) {
          await d.rawUpdate('UPDATE classifier_template SET options=? WHERE id=?', [
            jsonEncode({'targetKinds': ['object'], ...o, 'targetModuleId': target}),
            tid,
          ]);
        }
      }
      for (final (oid, tid, refs) in pendingLinks) {
        for (final r in refs) {
          final to = objByRef[r];
          if (to == null) continue;
          await d.insert('entity_relation',
              {'nexus_ref': nexusId, 'from_key': 'cobj_$oid', 'to_key': 'cobj_$to', 'rel_type': 'ctpl_$tid', 'directed': 1},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final (mid, refs) in pendingSelects) {
        final groups = [
          for (final r in refs)
            if (modByRef[r] case final int m) {
              'rules': [
                {'field': 'childOf', 'moduleId': m},
              ],
            },
        ];
        if (groups.isNotEmpty) await _ui(d, mid, 'filterDef', jsonEncode({'groups': groups}));
      }
      int? managerId;
      if (spec['manager'] != false && !bare) {
        managerId = await _module(d, nexusId, folderId, name, 'manager', color: col);
        await _ui(d, managerId, 'filterDef', jsonEncode({
          'groups': [
            {
              'rules': [
                {'field': 'childOf', 'moduleId': folderId},
              ],
            },
          ],
        }));
        await _projectPage(d, managerId, created, mods);
      }
      return (folderId: bare ? null : folderId, managerId: managerId, moduleIds: created);
    });
    // Index text once every row exists: a [[link]] to a module made later in
    // the same bundle resolves instead of dangling.
    await WikiService.rebuildIndex(db);
    return out;
  }
}

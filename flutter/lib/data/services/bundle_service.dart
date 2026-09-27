import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'page_template_service.dart';
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

  static const _collections = ['objects', 'events', 'chapters', 'dialogues', 'sessions', 'nodes', 'pages', 'tables'];

  /// Sample data out (v2 spec.includeSamples: false): a module marked
  /// `samples` loses its collections; an item marked `sample` goes by
  /// itself. Everything else is structure and stays.
  static Map withoutSamples(Map m) => {
        ...m,
        for (final c in _collections)
          if (m[c] is List) c: m['samples'] == true ? const [] : [for (final x in m[c] as List) if (!(x is Map && x['sample'] == true)) x],
      };

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
  static Future<({int? folderId, int? managerId, int? homeId, List<int> moduleIds})> create(
      Database db, int nexusId, int? parentId, Map<String, dynamic> spec) async {
    final name = _s(spec['name'], 200).trim();
    if (name.isEmpty) throw ArgumentError('name_required');
    final mods = [
      for (final m in _a(spec['modules']))
        if (m is Map && kinds.contains(m['kind']) && _s(m['name'], 200).trim().isNotEmpty)
          spec['includeSamples'] == false ? withoutSamples(m) : m,
    ].take(maxModules).toList();
    // v2: a module's page names a template; load them before the transaction
    final tpls = <String, PageTemplate>{};
    for (final m in mods) {
      for (final w in ['page', 'itemPage']) {
        final v = m[w];
        if (v is String && !tpls.containsKey(v)) {
          final t = await PageTemplateService.byId(v);
          if (t != null) tpls[v] = t;
        }
      }
    }
    final out = await db.transaction((d) async {
      final col = await _colorId(d, spec['color']);
      final bare = spec['folder'] == false;
      final folderId = bare ? parentId : await _module(d, nexusId, parentId, name, 'collector', icon: spec['icon'], color: col);
      // v2 folders, parents first; the root (no parent) is the project's own
      final folderIds = <String, int?>{};
      final folders = bare ? const [] : [for (final x in _a(spec['folders'])) if (x is Map && x['ref'] is String) x];
      final root = folders.where((x) => x['parent'] == null).firstOrNull;
      if (root != null) folderIds[root['ref'] as String] = folderId;
      for (var pass = 0; pass < folders.length && folderIds.length < folders.length; pass++) {
        for (final x in folders) {
          if (folderIds.containsKey(x['ref']) || !folderIds.containsKey(x['parent'])) continue;
          final fname = _s(x['name'], 200).trim();
          folderIds[x['ref'] as String] =
              await _module(d, nexusId, folderIds[x['parent']], fname.isEmpty ? x['ref'] as String : fname, 'collector', color: col);
        }
      }
      final pendingPages = <(int, Map)>[];
      final pendingUses = <(int, List)>[];
      final created = <int>[];
      final modByRef = <String, int>{};
      final objByRef = <String, int>{};
      final pendingFieldRel = <(int, String, Map<String, dynamic>)>[];
      final pendingLinks = <(int, int, List)>[];
      final pendingSelects = <(int, List)>[];
      for (final m in mods) {
        final kind = m['kind'] as String;
        final id = await _module(d, nexusId, folderIds[m['folder']] ?? folderId, _s(m['name'], 200).trim(), kind,
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
            // values / links name a field by key (v2) or by name (v1, guides)
            final tplByKey = <String, int>{};
            int? field(String k) => tplByKey[k] ?? tplByName[k];
            var fo = 0;
            for (final f in _a(m['fields'])) {
              if (f is! Map) continue;
              final raw = f['options'];
              final opts = <String, dynamic>{
                ...?(raw is String ? jsonDecode(raw) as Map<String, dynamic>? : raw as Map<String, dynamic>?),
                if (f['role'] != null) 'role': f['role'],
                if (f['key'] != null) 'key': '${f['key']}',
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
              if (f['key'] != null) tplByKey['${f['key']}'] = tid;
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
                final tid = field('${e.key}');
                if (tid == null) continue;
                final v = e.value;
                final val = v is List ? jsonEncode(v) : (v is bool ? (v ? '1' : '0') : _s(v));
                await d.insert('classifier_attribute', {'object_ref': oid, 'template_ref': tid, 'attribute_value': val},
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
              for (final e in (ob['links'] as Map? ?? const {}).entries) {
                final tid = field('${e.key}');
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
          case 'wanderer':
            if (_a(m['uses']).isNotEmpty) pendingUses.add((id, _a(m['uses'])));
        }
        if (m['page'] != null || m['itemPage'] != null) pendingPages.add((id, m));
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
      // A filter says "inside these". A Manager naming a module that is not
      // a folder selects the folder it sits in — the same modules, and the
      // ones added there later.
      for (final (mid, refs) in pendingSelects) {
        Future<Map<String, Object?>?> row(int id) async {
          final r = await d.rawQuery('SELECT kind, parent_id FROM module WHERE id=?', [id]);
          return r.firstOrNull;
        }

        final isManager = (await row(mid))?['kind'] == 'manager';
        final scope = <int>{};
        for (final r in refs) {
          final id = modByRef['$r'] ?? folderIds['$r'];
          if (id == null) continue;
          final m = await row(id);
          scope.add(isManager && m?['kind'] != 'collector' && m?['parent_id'] != null ? m!['parent_id'] as int : id);
        }
        final groups = [
          for (final id in scope)
            {
              'rules': [
                {'field': 'childOf', 'moduleId': id},
              ],
            },
        ];
        if (groups.isNotEmpty) await _ui(d, mid, 'filterDef', jsonEncode({'groups': groups}));
      }
      // A Wanderer walks a Locator's map along a Chronicler's time.
      for (final (wid, refs) in pendingUses) {
        for (final r in refs) {
          final tid = modByRef['$r'];
          if (tid == null) continue;
          final k = (await d.rawQuery('SELECT kind FROM module WHERE id=?', [tid])).firstOrNull?['kind'];
          if (k == 'locator') await _ui(d, wid, 'mapModule', '$tid');
          if (k == 'chronicler') await _ui(d, wid, 'timelineModule', '$tid');
        }
      }
      // Pages last: a template may borrow any module of the bundle. A
      // template id brings both its pages; an explicit itemPage wins.
      for (final (mid, m) in pendingPages) {
        final tpl = m['page'] is String ? tpls[m['page']] : null;
        for (final (which, itemKey) in [('page', null), ('itemPage', '*')]) {
          Object? blocks = m[which] ?? (which == 'page' ? tpl?.page : tpl?.itemPage);
          if (blocks is String) blocks = which == 'page' ? tpls[blocks]?.page : tpls[blocks]?.itemPage;
          if (blocks is! List || blocks.isEmpty) continue;
          await PageTemplateService.fillPage(d, mid, itemKey, blocks, modByRef);
        }
      }
      int? managerId;
      // a spec that brings its own Manager gets no second one
      final own = mods.indexWhere((m) => m['kind'] == 'manager');
      if (own >= 0) {
        managerId = created[own];
      } else if (spec['manager'] != false && !bare) {
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
      final homeId = spec['home'] is String ? modByRef[spec['home']] : null;
      return (folderId: bare ? null : folderId, managerId: managerId, homeId: homeId, moduleIds: created);
    });
    // Index text once every row exists: a [[link]] to a module made later in
    // the same bundle resolves instead of dangling.
    await WikiService.rebuildIndex(db);
    return out;
  }

  // ── "Save as Artisan bundle…" (APP docs/TEMPLATES.md §4.4) ──────────────
  // The port of EXE db/bundle-capture.js: a Collector's subtree as a v2
  // spec that [create] makes again — folders, modules with their look and
  // fields (a relation's target and an Exhibitor/Manager selection become
  // refs), each module's pages (a borrowed block keeps pointing inside the
  // bundle), and, when asked, up to three examples per module. Anything
  // that points outside the folder is left out. Stored in module_preset as
  // kind 'bundle', so it rides the vault and the snapshot like any preset.

  static const maxSamples = 3;

  static String _slug(String s) {
    final words = s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'f';
    return [
      for (final (i, w) in words.indexed) i == 0 ? w.toLowerCase() : w[0].toUpperCase() + w.substring(1).toLowerCase(),
    ].join();
  }

  static Map<String, dynamic>? _json(Object? v) {
    try {
      final o = v == null ? null : jsonDecode('$v');
      return o is Map ? o.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// [folderId]'s subtree as a bundle spec; [samples]: up to three examples
  /// per module (EXE captureBundle).
  static Future<Map<String, dynamic>> capture(DatabaseExecutor d, int folderId, {bool samples = false}) async {
    final roots = await d.rawQuery('SELECT id, name, kind, icon FROM module WHERE id=?', [folderId]);
    if (roots.isEmpty || roots.first['kind'] != 'collector') throw ArgumentError('not a folder');
    final root = roots.first;
    final all = <Map<String, Object?>>[];
    for (final q = [folderId]; q.isNotEmpty;) {
      final id = q.removeAt(0);
      for (final m in await d.rawQuery(
          'SELECT id, parent_id, name, kind, icon, cat_type, description FROM module WHERE parent_id=? ORDER BY display_order, id', [id])) {
        all.add(m);
        if (m['kind'] == 'collector') q.add(m['id'] as int);
      }
    }
    final inside = {folderId, for (final m in all) m['id'] as int};
    String ref(int id) => 'm$id';
    final folders = <Map<String, dynamic>>[
      {'ref': 'root', 'name': root['name']},
    ];
    final folderRef = <int, String>{folderId: 'root'};
    for (final m in all.where((x) => x['kind'] == 'collector')) {
      folderRef[m['id'] as int] = 'f${m['id']}';
      folders.add({'ref': 'f${m['id']}', 'name': m['name'], 'parent': folderRef[m['parent_id']]});
    }
    final objRef = <int, String>{};
    final fieldIds = <Map<String, dynamic>, int>{};
    final modules = <Map<String, dynamic>>[];
    for (final m in all.where((x) => x['kind'] != 'collector')) {
      final id = m['id'] as int;
      final kind = '${m['kind']}';
      final out = <String, dynamic>{'ref': ref(id), 'kind': kind, 'name': m['name'], 'folder': folderRef[m['parent_id']] ?? 'root'};
      if (m['icon'] != null && '${m['icon']}'.isNotEmpty) out['icon'] = m['icon'];
      if (m['description'] != null && '${m['description']}'.isNotEmpty) out['description'] = m['description'];
      if (kind == 'classifier') {
        out['catType'] = m['cat_type'] ?? 'object';
        final used = <String>{};
        out['fields'] = [
          for (final f in await d.rawQuery('''
              SELECT id, description AS name, attribute_type AS type, options, levelable, has_condition AS hasCondition
              FROM classifier_template WHERE module_ref=? AND object_ref IS NULL ORDER BY display_order, id''', [id]))
            () {
              final o = _json(f['options']) ?? <String, dynamic>{};
              var key = o['key'] is String ? o['key'] as String : _slug('${f['name'] ?? ''}');
              for (var n = 2; used.contains(key); n++) {
                key = '${_slug('${f['name'] ?? ''}')}$n';
              }
              used.add(key);
              final target = o.remove('targetModuleId');
              o.remove('key');
              final field = <String, dynamic>{'key': key, 'name': f['name'], 'type': f['type']};
              if (o.isNotEmpty) field['options'] = o;
              if (f['levelable'] == 1) field['levelable'] = true;
              if (f['hasCondition'] == 1) field['hasCondition'] = true;
              final t = target is num ? target.toInt() : int.tryParse('${target ?? ''}');
              if (t != null && inside.contains(t)) field['relTo'] = ref(t);
              fieldIds[field] = f['id'] as int;
              return field;
            }(),
        ];
      }
      final ui = {for (final r in await d.rawQuery('SELECT ui_key, ui_value FROM module_ui WHERE module_ref=?', [id])) '${r['ui_key']}': r['ui_value']};
      final sel = <int>[
        for (final g in (_json(ui['filterDef'])?['groups'] as List?) ?? const [])
          for (final r in ((g is Map ? g['rules'] : null) as List?) ?? const [])
            if (r is Map && r['field'] == 'childOf' && r['moduleId'] is num && (folderRef.containsKey((r['moduleId'] as num).toInt()) || inside.contains((r['moduleId'] as num).toInt())))
              (r['moduleId'] as num).toInt(),
      ];
      if (sel.isNotEmpty && (kind == 'exhibitor' || kind == 'manager')) out['selects'] = [for (final s in sel) folderRef[s] ?? ref(s)];
      if (kind == 'wanderer') {
        final uses = [
          for (final k in ['mapModule', 'timelineModule'])
            if (int.tryParse('${ui[k] ?? ''}') case final u? when inside.contains(u)) ref(u),
        ];
        if (uses.isNotEmpty) out['uses'] = uses;
      }
      Object? borrow(String sk) {
        final b = int.tryParse(sk.replaceFirst(RegExp(r'^module_'), ''));
        return b != null && inside.contains(b) ? ref(b) : null;
      }

      final page = await PageTemplateService.capturePage(d, id, null, borrowRef: borrow);
      final itemPage = await PageTemplateService.capturePage(d, id, '*', borrowRef: borrow);
      if (page.isNotEmpty) out['page'] = page;
      if (itemPage.isNotEmpty) out['itemPage'] = itemPage;
      if (samples) {
        if (kind == 'classifier') {
          out['objects'] = [
            for (final o in await d.rawQuery('SELECT id, name, note FROM classifier_object WHERE module_ref=? ORDER BY id LIMIT ?', [id, maxSamples]))
              await () async {
                objRef[o['id'] as int] = 'o${o['id']}';
                final ob = <String, dynamic>{'ref': 'o${o['id']}', 'sample': true, 'name': o['name']};
                if (o['note'] != null && '${o['note']}'.isNotEmpty) ob['note'] = o['note'];
                for (final f in (out['fields'] as List).cast<Map<String, dynamic>>()) {
                  if (f['type'] == 'relation') continue;
                  final v = await d.rawQuery('SELECT attribute_value AS v FROM classifier_attribute WHERE object_ref=? AND template_ref=?', [o['id'], fieldIds[f]]);
                  final val = v.isEmpty ? null : v.first['v'];
                  if (val != null && '$val'.isNotEmpty) ((ob['values'] ??= <String, dynamic>{}) as Map)[f['key']] = val;
                }
                return ob;
              }(),
          ];
        }
        if (kind == 'chronicler') {
          out['events'] = [
            for (final e in await d.rawQuery('''
                SELECT e.event_name AS name, e.story, dt.years AS y, dt.month AS mo, dt.day AS dy
                FROM timeline_event e JOIN timeline t ON t.id=e.timeline_id LEFT JOIN timeline_date dt ON dt.id=e.start_at
                WHERE t.module_ref=? ORDER BY e.id LIMIT ?''', [id, maxSamples]))
              {
                'sample': true,
                'name': e['name'],
                if (e['story'] != null && '${e['story']}'.isNotEmpty) 'story': e['story'],
                'date': [e['y'] ?? 1, e['mo'] ?? 1, e['dy'] ?? 1],
              },
          ];
        }
        if (kind == 'author') {
          out['chapters'] = [
            for (final c in await d.rawQuery(
                'SELECT name, chapter_content AS content, synopsis, status FROM book_chapter WHERE module_ref=? ORDER BY chapter_order, id LIMIT ?', [id, maxSamples]))
              {
                'sample': true,
                'name': c['name'],
                for (final k in ['content', 'synopsis', 'status'])
                  if (c[k] != null && '${c[k]}'.isNotEmpty) k: c[k],
              },
          ];
        }
      }
      modules.add(out);
    }
    // links between captured examples, through relation fields that stay inside
    if (samples) {
      for (final m in modules.where((x) => x['kind'] == 'classifier')) {
        final rel = [for (final f in (m['fields'] as List).cast<Map<String, dynamic>>()) if (f['type'] == 'relation' && f['relTo'] != null) f];
        for (final ob in ((m['objects'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
          final oid = int.parse('${ob['ref']}'.substring(1));
          for (final f in rel) {
            final to = [
              for (final r in await d.rawQuery('SELECT to_key FROM entity_relation WHERE from_key=? AND rel_type=?', ['cobj_$oid', 'ctpl_${fieldIds[f]}']))
                ?objRef[int.tryParse('${r['to_key']}'.replaceFirst('cobj_', '')) ?? -1],
            ];
            if (to.isNotEmpty) ((ob['links'] ??= <String, dynamic>{}) as Map)[f['key']] = to;
          }
        }
      }
    }
    final manager = modules.where((m) => m['kind'] == 'manager').firstOrNull;
    return {
      'name': root['name'],
      'icon': root['icon'],
      'folders': folders,
      'modules': modules,
      if (manager != null) 'home': manager['ref'],
    };
  }

  /// Save [folderId] as one of the user's bundles; the same name replaces.
  /// Returns how many modules it holds.
  static Future<int> saveMine(Database db, int nexusId, int folderId, String name, {bool samples = false}) async {
    final n = name.trim().length > 120 ? name.trim().substring(0, 120) : name.trim();
    if (n.isEmpty) throw ArgumentError('name required');
    final spec = await capture(db, folderId, samples: samples);
    await db.rawInsert('''
      INSERT INTO module_preset (nexus_ref, kind, name, spec) VALUES (?, 'bundle', ?, ?)
      ON CONFLICT(nexus_ref, kind, name) DO UPDATE SET spec=excluded.spec, update_at=datetime('now')''', [nexusId, n, jsonEncode(spec)]);
    return (spec['modules'] as List).length;
  }

  /// The user's own bundles ("Mine" in the Artisan sheet), as picker
  /// entries shaped like the catalog's.
  static Future<List<Map<String, dynamic>>> listMine(DatabaseExecutor d, int nexusId) async => [
        for (final r in await d.rawQuery("SELECT id, name, spec FROM module_preset WHERE nexus_ref=? AND kind='bundle' ORDER BY name COLLATE NOCASE", [nexusId]))
          {
            'id': 'u:${r['id']}',
            'group': 'mine',
            'name': r['name'],
            'spec': _json(r['spec']) ?? {'modules': <Object?>[]},
          },
      ];

  /// Whether a spec carries examples the Adjust step can leave out.
  static bool hasSamples(Map spec) => _a(spec['modules']).any((m) =>
      m is Map && (m['samples'] == true || _collections.any((c) => _a(m[c]).any((o) => o is Map && o['sample'] == true))));

  /// Blocks that borrow a module the user left out have nothing to show.
  static List keepBorrows(List blocks, Set<String> kept) => [
        for (final b in blocks)
          if (b is! Map || b['borrow'] is! String || kept.contains(b['borrow']))
            b is Map && b['children'] is List
                ? {...b, 'children': [for (final c in b['children'] as List) c is List ? keepBorrows(c, kept) : c]}
                : b,
      ];

  /// "Adjust first": [spec] with only the modules at [keep] (indexes), each
  /// renamed by [names] and its fields by [fieldNames] ('i:k' → name; a
  /// blank name leaves that field out). Anything pointing at a module left
  /// out — a relation field, a selection, a Wanderer's map or timeline, a
  /// borrowed block, the home — goes with it (EXE submitBundleAdjust).
  static Map<String, dynamic> adjust(Map<String, dynamic> spec,
      {required String name, required Set<int> keep, Map<int, String> names = const {}, Map<String, String> fieldNames = const {}, bool includeSamples = true}) {
    final mods = _a(spec['modules']);
    final kept = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final (i, m) in mods.indexed) {
      if (m is! Map || !keep.contains(i)) continue;
      final nm = (names[i] ?? '').trim();
      final fields = m['fields'] is List
          ? [
              for (final (k, f) in (m['fields'] as List).indexed)
                if (f is Map)
                  if ((fieldNames['$i:$k'] ?? '${f['name'] ?? ''}').trim() case final fn when fn.isNotEmpty) {...f, 'name': fn},
            ]
          : null;
      if (m['ref'] is String) kept.add(m['ref'] as String);
      out.add({...m.cast<String, dynamic>(), 'name': nm.isEmpty ? m['name'] : nm, 'fields': ?fields});
    }
    final folderRefs = {for (final f in _a(spec['folders'])) if (f is Map) '${f['ref']}'};
    for (final m in out) {
      if (m['fields'] is List) {
        m['fields'] = [
          for (final f in m['fields'] as List)
            f is Map && f['relTo'] != null && !kept.contains(f['relTo']) ? ({...f}..remove('relTo')) : f,
        ];
      }
      if (m['selects'] is List) m['selects'] = [for (final r in m['selects'] as List) if (kept.contains(r) || folderRefs.contains(r)) r];
      if (m['uses'] is List) m['uses'] = [for (final r in m['uses'] as List) if (kept.contains(r)) r];
      for (final k in ['page', 'itemPage']) {
        if (m[k] is List) m[k] = keepBorrows(m[k] as List, kept);
      }
    }
    final res = <String, dynamic>{...spec, 'name': name, 'modules': out};
    if (res['home'] != null && !kept.contains(res['home'])) res.remove('home');
    if (!includeSamples) res['includeSamples'] = false;
    return res;
  }

  // ── The Artisan gallery's preview (mockup 08-artisan.html) ─────────────
  // EXE hub/bundles.js bundleShape: what a spec will build, read from the
  // same spec [create] builds from — so the preview and the result agree.

  /// Examples a module carries (a module marked `samples`: all of them).
  static int samplesOf(Map m) => [
        for (final c in const ['objects', 'events', 'chapters', 'dialogues', 'sessions'])
          m['samples'] == true ? _a(m[c]).length : _a(m[c]).where((o) => o is Map && o['sample'] == true).length,
      ].fold(0, (a, b) => a + b);

  /// A spec's folders and modules as a tree, its links between modules —
  /// relation field, selection, a Wanderer's map/time; a page block
  /// borrowing another module (`borrow: true`) — and its example count.
  static BundleShape shape(Map spec) {
    final mods = [for (final m in _a(spec['modules'])) if (m is Map) m];
    final refs = {for (final m in mods) if (m['ref'] is String) m['ref'] as String};
    final links = <BundleLink>[];
    void add(Object? from, Object? to, {bool borrow = false}) {
      if (from is! String || to is! String || from == to || !refs.contains(to)) return;
      if (links.any((l) => l.from == from && l.to == to)) return;
      links.add(BundleLink(from, to, borrow));
    }

    void walk(Object? blocks, Object? from) {
      for (final b in _a(blocks)) {
        if (b is! Map) continue;
        if (b['borrow'] is String) add(from, b['borrow'], borrow: true);
        for (final c in _a(b['children'])) {
          walk(c, from);
        }
      }
    }

    for (final m in mods) {
      for (final f in _a(m['fields'])) {
        if (f is Map) add(m['ref'], f['relTo']);
      }
      for (final r in _a(m['selects'])) {
        add(m['ref'], r);
      }
      for (final r in _a(m['uses'])) {
        add(m['ref'], r);
      }
      walk(m['page'], m['ref']);
      walk(m['itemPage'], m['ref']);
    }
    final folders = [for (final f in _a(spec['folders'])) if (f is Map) f];
    if (folders.isEmpty) folders.add({'ref': 'root', 'name': spec['name']});
    final rows = <BundleRow>[];
    final seen = <Map>{};
    void visit(Map f, int depth) {
      rows.add(BundleRow(depth, '${f['name'] ?? ''}', null, 0));
      for (final m in mods.where((m) => (m['folder'] ?? 'root') == f['ref'])) {
        seen.add(m);
        rows.add(BundleRow(depth + 1, '${m['name'] ?? ''}', '${m['kind']}', samplesOf(m)));
      }
      for (final c in folders.where((c) => c['parent'] == f['ref'])) {
        visit(c, depth + 1);
      }
    }

    for (final f in folders.where((f) => f['parent'] == null)) {
      visit(f, 0);
    }
    for (final m in mods.where((m) => !seen.contains(m))) {
      rows.add(BundleRow(1, '${m['name'] ?? ''}', '${m['kind']}', samplesOf(m)));
    }
    return BundleShape(
      rows,
      [for (final m in mods) if (m['ref'] is String) (ref: m['ref'] as String, name: '${m['name'] ?? ''}', kind: '${m['kind']}')],
      folders.length,
      links,
      mods.fold(0, (n, m) => n + samplesOf(m)),
    );
  }
}

/// A row of [BundleService.shape]'s tree: a folder ([kind] null) or a module.
class BundleRow {
  final int depth;
  final String name;
  final String? kind;
  final int samples;
  const BundleRow(this.depth, this.name, this.kind, this.samples);
}

/// A link between two modules of a bundle; [borrow]: a page block borrowing.
class BundleLink {
  final String from, to;
  final bool borrow;
  const BundleLink(this.from, this.to, this.borrow);
}

class BundleShape {
  final List<BundleRow> rows;
  final List<({String ref, String name, String kind})> mods;
  final int folders, samples;
  final List<BundleLink> links;
  const BundleShape(this.rows, this.mods, this.folders, this.links, this.samples);
}

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';

/// One page_block row.
class PageBlock {
  final int id;
  final int moduleId;
  final String? itemKey;
  final int? parentId;

  /// component · text · heading · divider · image · property · columns
  final String type;
  final String? component;
  final String? sourceKey;
  final Map<String, Object?> config;
  final String? content;
  final String? propName;
  final String? propType;
  final int order;

  const PageBlock({
    required this.id,
    required this.moduleId,
    this.itemKey,
    this.parentId,
    required this.type,
    this.component,
    this.sourceKey,
    this.config = const {},
    this.content,
    this.propName,
    this.propType,
    this.order = 0,
  });

  factory PageBlock.fromMap(Map<String, Object?> r) {
    var config = <String, Object?>{};
    final raw = r['config'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) config = d.cast<String, Object?>();
      } catch (_) {}
    }
    return PageBlock(
      id: r['id'] as int,
      moduleId: r['module_ref'] as int,
      itemKey: r['item_key'] as String?,
      parentId: r['parent_id'] as int?,
      type: r['block_type'] as String? ?? 'component',
      component: r['component'] as String?,
      sourceKey: r['source_key'] as String?,
      config: config,
      content: r['content'] as String?,
      propName: r['prop_name'] as String?,
      propType: r['prop_type'] as String?,
      order: r['block_order'] as int? ?? 0,
    );
  }

  /// A columns block's child sits in column `config.col` (0-based).
  int get column => (config['col'] as num?)?.toInt() ?? 0;

  /// The preset a component block shows, when it names one.
  String? get preset => config['preset'] as String?;
}

/// Where a page's blocks came from: its own rows, the shared element layout
/// (an element page not split off yet), or nowhere.
enum PageSource { own, shared, none }

/// A block to lay down: what [PageBlockDao.ensurePage] and [PageBlockDao.add]
/// take.
class NewBlock {
  final String type;
  final String? component;
  final Map<String, Object?>? config;
  final String? content;
  final String? sourceKey;
  final int? parentId;
  final String? propName;
  final String? propType;

  const NewBlock({
    this.type = 'component',
    this.component,
    this.config,
    this.content,
    this.sourceKey,
    this.parentId,
    this.propName,
    this.propType,
  });
}

/// Pages made of blocks (v5 Part 8, APP docs/V5.md §12; APK-V3.md §10.4) —
/// the port of EXE `db/page-block.js`. Which page a row is on is
/// (module_ref, item_key):
///   item_key NULL        the module's own page
///   item_key '*'         the layout every element page of the module shares
///   item_key `<key>`     one element's own page, split off the shared one
/// Property rows are rows too, but a page never stacks them one by one: the
/// Properties component lists them, so [list] leaves them out and [props]
/// returns them.
///
/// Version history is the desktop's alone (the APK has none, §10.5), so the
/// desktop's recordVersion calls have no counterpart here.
class PageBlockDao {
  final Database db;
  PageBlockDao(this.db);

  static const _stack = "block_type<>'property'";
  static String _where(String? itemKey) => itemKey == null ? 'item_key IS NULL' : 'item_key=?';
  static List<Object?> _args(int moduleId, String? itemKey) => itemKey == null ? [moduleId] : [moduleId, itemKey];
  static String? _initKey(String? itemKey) => itemKey == null ? 'pageInit' : (itemKey == '*' ? 'itemPageInit' : null);

  Future<List<PageBlock>> _stackRows(DatabaseExecutor d, int moduleId, String? itemKey) async => [
        for (final r in await d.rawQuery(
            'SELECT * FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND $_stack ORDER BY block_order, id',
            _args(moduleId, itemKey)))
          PageBlock.fromMap(r),
      ];

  /// The page (module or element) whose text a block indexes under.
  Future<void> _reindex(DatabaseExecutor d, int moduleId, String? itemKey) async {
    try {
      if (itemKey == null) {
        await WikiService.reindexSource(d, 'module', moduleId);
      } else if (RegExp(r'^cobj_\d+$').hasMatch(itemKey)) {
        await WikiService.reindexSource(d, 'cobj', int.parse(itemKey.substring(5)));
      }
    } catch (_) {}
  }

  /// An element page falls back to the shared layout until it is split.
  Future<({List<PageBlock> blocks, PageSource from})> list(int moduleId, [String? itemKey]) async {
    var rows = await _stackRows(db, moduleId, itemKey);
    var from = rows.isEmpty ? PageSource.none : PageSource.own;
    if (rows.isEmpty && itemKey != null && itemKey != '*') {
      rows = await _stackRows(db, moduleId, '*');
      if (rows.isNotEmpty) from = PageSource.shared;
    }
    return (blocks: rows, from: from);
  }

  Future<List<PageBlock>> props(int moduleId, [String? itemKey]) async => [
        for (final r in await db.rawQuery(
            "SELECT * FROM page_block WHERE module_ref=? AND ${_where(itemKey)} AND block_type='property' "
            'ORDER BY block_order, id',
            _args(moduleId, itemKey)))
          PageBlock.fromMap(r),
      ];

  /// Lays a page out the first time it opens. A page is laid out ONCE
  /// (module_ui pageInit / itemPageInit), so a user who removed every block
  /// does not get them back on the next open. True when it laid one out.
  Future<bool> ensurePage(int moduleId, String? itemKey, List<NewBlock> defaults) async {
    final key = _initKey(itemKey);
    if (key == null) return false;
    var laid = false;
    await db.transaction((d) async {
      final seen = await d.rawQuery('SELECT 1 FROM module_ui WHERE module_ref=? AND ui_key=?', [moduleId, key]);
      if (seen.isNotEmpty) return;
      if ((await _stackRows(d, moduleId, itemKey)).isEmpty) {
        for (var i = 0; i < defaults.length; i++) {
          final b = defaults[i];
          await d.insert('page_block', {
            'module_ref': moduleId,
            'item_key': itemKey,
            'block_type': b.type,
            'component': b.component,
            'config': b.config == null ? null : jsonEncode(b.config),
            'content': b.content,
            'block_order': i,
          });
        }
      }
      await d.rawInsert("INSERT OR IGNORE INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,'1')", [moduleId, key]);
      laid = true;
    });
    return laid;
  }

  /// Adds a block; [at] inserts before that index, else at the end.
  Future<int> add(int moduleId, String? itemKey, NewBlock b, {int? at}) async {
    late int id;
    await db.transaction((d) async {
      var order = (await d.rawQuery(
              'SELECT COALESCE(MAX(block_order),-1)+1 AS n FROM page_block WHERE module_ref=? AND ${_where(itemKey)}',
              _args(moduleId, itemKey)))
          .first['n'] as int;
      if (at != null) {
        order = at;
        await d.rawUpdate(
            'UPDATE page_block SET block_order=block_order+1 WHERE module_ref=? AND ${_where(itemKey)} AND block_order>=?',
            [..._args(moduleId, itemKey), order]);
      }
      id = await d.insert('page_block', {
        'module_ref': moduleId,
        'item_key': itemKey,
        'parent_id': b.parentId,
        'block_type': b.type,
        'component': b.component,
        'source_key': b.sourceKey,
        'config': b.config == null ? null : jsonEncode(b.config),
        'content': b.content,
        'prop_name': b.propName,
        'prop_type': b.propType,
        'block_order': order,
      });
      if (b.content != null && b.content!.isNotEmpty) await _reindex(d, moduleId, itemKey);
    });
    return id;
  }

  Future<PageBlock?> get(int id) async {
    final r = await db.rawQuery('SELECT * FROM page_block WHERE id=?', [id]);
    return r.isEmpty ? null : PageBlock.fromMap(r.first);
  }

  /// Sets any of content / config / propName / propType / sourceKey /
  /// parentId. [clear] names fields to set to NULL explicitly.
  Future<void> update(
    int id, {
    String? content,
    Map<String, Object?>? config,
    String? propName,
    String? propType,
    String? sourceKey,
    int? parentId,
    Set<String> clear = const {},
  }) async {
    final prev = await get(id);
    if (prev == null) return;
    final sets = <String>[];
    final vals = <Object?>[];
    void set(String name, String col, Object? v) {
      if (v != null || clear.contains(name)) {
        sets.add('$col=?');
        vals.add(v);
      }
    }

    set('content', 'content', content);
    set('config', 'config', config == null ? null : jsonEncode(config));
    set('propName', 'prop_name', propName);
    set('propType', 'prop_type', propType);
    set('sourceKey', 'source_key', sourceKey);
    set('parentId', 'parent_id', parentId);
    if (sets.isEmpty) return;
    await db.rawUpdate("UPDATE page_block SET ${sets.join(', ')}, update_at=datetime('now') WHERE id=?", [...vals, id]);
    if (content != null || propName != null || clear.contains('content')) {
      await _reindex(db, prev.moduleId, prev.itemKey);
    }
  }

  /// Moves a block to index [to] among its siblings — the same page, the same
  /// parent (a columns block's children reorder among themselves), and the
  /// same list (properties apart from the stack).
  Future<void> move(int id, int to) async {
    final b = await get(id);
    if (b == null) return;
    await db.transaction((d) async {
      final kinds = b.type == 'property' ? "block_type='property'" : _stack;
      final parent = b.parentId == null ? 'parent_id IS NULL' : 'parent_id=${b.parentId}';
      final ids = [
        for (final r in await d.rawQuery(
            'SELECT id FROM page_block WHERE module_ref=? AND ${_where(b.itemKey)} AND $kinds AND $parent '
            'ORDER BY block_order, id',
            _args(b.moduleId, b.itemKey)))
          r['id'] as int,
      ]..remove(id);
      ids.insert(to.clamp(0, ids.length), id);
      for (var i = 0; i < ids.length; i++) {
        await d.rawUpdate('UPDATE page_block SET block_order=? WHERE id=?', [i, ids[i]]);
      }
    });
  }

  /// Deletes a block and its children; returns the rows, for an Undo that
  /// hands them to [restore].
  Future<List<Map<String, Object?>>> delete(int id) async {
    final prev = await db.rawQuery('SELECT * FROM page_block WHERE id=?', [id]);
    if (prev.isEmpty) return const [];
    final kids = await db.rawQuery('SELECT * FROM page_block WHERE parent_id=?', [id]);
    await db.rawDelete('DELETE FROM page_block WHERE id=?', [id]);
    final first = PageBlock.fromMap(prev.first);
    if (first.content != null) await _reindex(db, first.moduleId, first.itemKey);
    return [...prev, ...kids];
  }

  /// Puts rows back exactly, ids included — the undo of a delete.
  Future<void> restore(List<Map<String, Object?>> rows) async {
    await db.transaction((d) async {
      for (final r in rows) {
        if ((await d.rawQuery('SELECT 1 FROM module WHERE id=?', [r['module_ref']])).isEmpty) continue;
        await d.insert('page_block', r, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    if (rows.isNotEmpty) {
      await _reindex(db, rows.first['module_ref'] as int, rows.first['item_key'] as String?);
    }
  }

  /// Gives one element its own copy of the shared layout.
  Future<bool> split(int moduleId, String itemKey) async {
    if (itemKey == '*') return false;
    var done = false;
    await db.transaction((d) async {
      if ((await _stackRows(d, moduleId, itemKey)).isNotEmpty) return;
      final map = <int, int>{};
      for (final r in await _stackRows(d, moduleId, '*')) {
        final id = await d.insert('page_block', {
          'module_ref': moduleId,
          'item_key': itemKey,
          'parent_id': r.parentId == null ? null : map[r.parentId],
          'block_type': r.type,
          'component': r.component,
          'source_key': r.sourceKey,
          'config': r.config.isEmpty ? null : jsonEncode(r.config),
          'content': r.content,
          'prop_name': r.propName,
          'prop_type': r.propType,
          'block_order': r.order,
        });
        map[r.id] = id;
      }
      done = true;
    });
    return done;
  }

  /// Back to the shared layout: the element's own stack goes; its
  /// properties stay — they are its data, not its layout.
  Future<bool> revert(int moduleId, String itemKey) async {
    if (itemKey == '*') return false;
    final n = await db.rawDelete('DELETE FROM page_block WHERE module_ref=? AND item_key=? AND $_stack', [moduleId, itemKey]);
    if (n > 0) await _reindex(db, moduleId, itemKey);
    return n > 0;
  }

  /// An element was deleted: its page goes, and a borrowed component that
  /// showed it shows nothing.
  Future<void> clearItem(String key) async {
    if (key == '*') return;
    await db.rawDelete('DELETE FROM page_block WHERE item_key=?', [key]);
    await db.rawUpdate('UPDATE page_block SET source_key=NULL WHERE source_key=?', [key]);
  }

  /// Adds or edits one property.
  Future<int> setProp(int moduleId, String? itemKey, int? id, String name, String? value, {String type = 'text'}) async {
    if (id != null) {
      await update(id, propName: name, content: value, propType: type, clear: {if (value == null) 'content'});
      return id;
    }
    return add(moduleId, itemKey, NewBlock(type: 'property', propName: name, propType: type, content: value));
  }
}

import 'package:sqflite/sqflite.dart';

import 'vault_schema.g.dart';

/// Brings a database created by an older build up to the vendored schema
/// (APP docs/APK-V3.md §2). `CREATE TABLE IF NOT EXISTS` — what [DatabaseHelper]
/// runs on every open — adds tables but never changes one that exists, so an
/// install from before SDB 2.0 keeps its v4 tables: no v5 columns, the old
/// `module.kind` CHECK (no `exhibitor`, no `diviner`), the old
/// `entity_relation` UNIQUE, `design_node`'s shape CHECK.
///
/// EXE fixes the same drift with a list of hand-written migrations
/// (`db/schema/migrations.js`). This side reads what to do off the vendored
/// DDL itself, table by table:
///
///  * a missing column that `ALTER TABLE ADD COLUMN` can take is added;
///  * a table that needs anything ALTER cannot do — a changed CHECK, a
///    changed UNIQUE, a missing column with a non-constant default or a
///    NOT NULL without one — is rebuilt from the vendored DDL, copying every
///    column the two share, ids included (so every foreign key into it keeps
///    pointing at the same rows).
///
/// The data half of EXE's migrations comes along where it matters here:
/// `viewer`/`connector` modules become `exhibitor` with the view they had
/// (`migrateModuleKindV5`), and relations that the new UNIQUE would reject
/// are deduplicated first (`migrateEntityRelationV5`).
///
/// Every step is idempotent: a second open finds nothing to do.
class VaultUpgrade {
  /// What the last [run] changed — for tests and for a one-line log.
  final List<String> log = [];

  static final _createRe = RegExp(r'CREATE TABLE IF NOT EXISTS (\w+) \(');

  /// name → vendored `CREATE TABLE` text (comments stripped).
  static final Map<String, String> vendored = {
    for (final sql in vaultCreateStatements)
      if (_createRe.hasMatch(sql)) _createRe.firstMatch(sql)!.group(1)!: _stripComments(sql),
  };

  static String _stripComments(String sql) =>
      sql.split('\n').map((l) => l.replaceFirst(RegExp(r'--.*$'), '')).join('\n');

  /// The body between the outer parentheses of a CREATE TABLE.
  static String _body(String create) {
    final open = create.indexOf('(');
    var depth = 0;
    for (var i = open; i < create.length; i++) {
      final c = create[i];
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) return create.substring(open + 1, i);
    }
    return create.substring(open + 1);
  }

  /// Top-level comma split (commas inside a CHECK(...) list stay).
  static List<String> _parts(String body) {
    final out = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        out.add(body.substring(start, i).trim());
        start = i + 1;
      }
    }
    out.add(body.substring(start).trim());
    return out.where((p) => p.isNotEmpty).toList();
  }

  static const _constraintWords = {'PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'};

  /// Column name → its definition, from vendored DDL.
  static Map<String, String> columnDefs(String table) {
    final create = vendored[table];
    if (create == null) return const {};
    final out = <String, String>{};
    for (final p in _parts(_body(create))) {
      // `UNIQUE(a,b)` has no space before its parenthesis: split on both.
      final first = p.split(RegExp(r'[\s(]+')).first;
      if (_constraintWords.contains(first.toUpperCase())) continue;
      out[first] = p;
    }
    return out;
  }

  /// Whether `ALTER TABLE … ADD COLUMN <def>` is legal in SQLite.
  static bool alterable(String def) {
    final up = def.toUpperCase();
    if (up.contains('PRIMARY KEY') || up.contains('UNIQUE')) return false;
    final dflt = RegExp(r'DEFAULT\s+(\(|[^\s,]+)', caseSensitive: false).firstMatch(def);
    // A parenthesised default is an expression (datetime('now')): ALTER
    // refuses those.
    if (dflt != null && dflt.group(1) == '(') return false;
    if (up.contains('NOT NULL') && dflt == null) return false;
    return true;
  }

  static Future<List<String>> _columns(DatabaseExecutor db, String table) async =>
      [for (final r in await db.rawQuery('PRAGMA table_info($table)')) r['name'] as String];

  static Future<String?> _storedSql(DatabaseExecutor db, String table) async {
    final r = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", [table]);
    return r.isEmpty ? null : r.first['sql'] as String?;
  }

  Future<void> run(Database db) async {
    log.clear();
    final rebuild = <String>{};
    for (final table in vendored.keys) {
      final stored = await _storedSql(db, table);
      if (stored == null) continue; // IF NOT EXISTS makes it
      if (await _needsRebuild(table, stored)) {
        rebuild.add(table);
        continue;
      }
      final have = (await _columns(db, table)).toSet();
      final defs = columnDefs(table);
      for (final e in defs.entries) {
        if (have.contains(e.key)) continue;
        if (!alterable(e.value)) {
          rebuild.add(table);
          break;
        }
        await db.execute('ALTER TABLE $table ADD COLUMN ${e.value}');
        log.add('+ $table.${e.key}');
      }
    }
    // module first: every other rebuild's foreign keys lead back to it.
    final ordered = [
      if (rebuild.contains('module')) 'module',
      ...rebuild.where((t) => t != 'module'),
    ];
    for (final table in ordered) {
      await _rebuild(db, table);
    }
    if (rebuild.contains('entity_relation') || !(await _hasIndex(db, 'idx_entity_relation_v5'))) {
      await _dedupeRelations(db);
    }
  }

  /// A rebuild is for what ALTER cannot express: a CHECK or UNIQUE that
  /// changed. Compared by the constraint text, never the whole table text —
  /// the stored DDL keeps comments and whitespace a build happened to have.
  Future<bool> _needsRebuild(String table, String stored) async {
    String norm(String s) => _stripComments(s)
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r' ?\( ?'), '(')
        .replaceAll(RegExp(r' ?\) ?'), ')')
        .replaceAll(RegExp(r' ?, ?'), ',')
        .toUpperCase();
    final want = norm(vendored[table]!);
    final have = norm(stored);
    Iterable<String> checks(String s) => RegExp(r'CHECK\((?:[^()]|\([^()]*\))*\)').allMatches(s).map((m) => m[0]!);
    Iterable<String> uniques(String s) => RegExp(r'UNIQUE\([^)]*\)').allMatches(s).map((m) => m[0]!);
    return !_sameSet(checks(want), checks(have)) || !_sameSet(uniques(want), uniques(have));
  }

  static bool _sameSet(Iterable<String> a, Iterable<String> b) {
    final x = a.toSet();
    final y = b.toSet();
    return x.length == y.length && x.containsAll(y);
  }

  Future<bool> _hasIndex(DatabaseExecutor db, String name) async =>
      (await db.rawQuery("SELECT 1 FROM sqlite_master WHERE type='index' AND name=?", [name])).isNotEmpty;

  Future<void> _rebuild(Database db, String table) async {
    final newName = '${table}_upgrade_new';
    final create = vendored[table]!.replaceFirst('CREATE TABLE IF NOT EXISTS $table (', 'CREATE TABLE $newName (');
    // PRAGMA foreign_keys is a no-op inside a transaction, so it is switched
    // around one: with it on, the DROP would cascade into every child table.
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        if (table == 'module') await _moduleKindData(txn);
        await txn.execute('DROP TABLE IF EXISTS $newName');
        await txn.execute(create);
        final have = (await _columns(txn, table)).toSet();
        final keep = (await _columns(txn, newName)).where(have.contains).toList();
        final sel = keep
            .map((c) => table == 'module' && c == 'kind'
                ? "CASE WHEN kind IN ('viewer','connector') THEN 'exhibitor' ELSE kind END"
                : c)
            .join(', ');
        if (table == 'entity_relation') {
          // The v5 UNIQUE would reject what the old one let through (NULL
          // labels were never deduplicated) — keep the first of each.
          await txn.execute('INSERT INTO $newName (${keep.join(', ')}) SELECT $sel FROM $table '
              "WHERE id IN (SELECT MIN(id) FROM $table GROUP BY from_key, to_key, COALESCE(label,''))");
        } else {
          await txn.execute('INSERT INTO $newName (${keep.join(', ')}) SELECT $sel FROM $table');
        }
        await txn.execute('DROP TABLE $table');
        await txn.execute('ALTER TABLE $newName RENAME TO $table');
      });
      log.add('rebuilt $table');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// `migrateModuleKindV5`'s data half: a Connector opens as the Scene (its
  /// edge list as Edges), a Viewer keeps a table/cards/board view.
  Future<void> _moduleKindData(Transaction txn) async {
    final rows = await txn.rawQuery("SELECT id, kind FROM module WHERE kind IN ('viewer','connector')");
    for (final m in rows) {
      final v = await txn.rawQuery(
          "SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='activeView'", [m['id']]);
      final view = v.isEmpty ? null : v.first['ui_value'];
      Future<void> set(String key, String value) => txn.execute(
          'INSERT INTO module_ui (module_ref, ui_key, ui_value) VALUES (?,?,?) '
          'ON CONFLICT(module_ref, ui_key) DO UPDATE SET ui_value=excluded.ui_value',
          [m['id'], key, value]);
      if (m['kind'] == 'connector') {
        await set('activeView', view == 'edgelist' ? 'edges' : 'scene');
        await set('seedScene', '1');
      } else {
        await set('activeView', const {'table', 'cards', 'board'}.contains(view) ? '$view' : 'table');
      }
    }
  }

  Future<void> _dedupeRelations(Database db) async {
    final cols = await _columns(db, 'entity_relation');
    if (!cols.contains('rel_type')) return;
    final removed = await db.rawDelete('DELETE FROM entity_relation WHERE id NOT IN ('
        'SELECT MIN(id) FROM entity_relation '
        "GROUP BY from_key, to_key, COALESCE(label,''), COALESCE(rel_type,''))");
    if (removed > 0) log.add('- $removed duplicate relation(s)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_entity_relation_v5 ON entity_relation '
        "(from_key, to_key, COALESCE(label,''), COALESCE(rel_type,''))");
  }
}

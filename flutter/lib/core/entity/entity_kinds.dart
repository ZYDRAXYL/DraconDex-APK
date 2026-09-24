import 'package:sqflite/sqflite.dart';

import 'entity_kinds.g.dart';

export 'entity_kinds.g.dart';

/// The vendored key families (DraconDex-SDB schema/entity-kinds.json, APP
/// docs/APK-V3.md §9.1) and what the app does with them. EXE reads the same
/// file, so the two importers remap exactly the same families and columns.
class EntityKinds {
  static final keyRe = RegExp(r'^([a-z]+)_(\d+)$');

  static final Map<String, EntityFamily> byPrefix = {for (final f in entityFamilies) f.prefix: f};

  /// `cobj_12` → (cobj, 12); null for anything that is not a key.
  static (String, int)? parse(Object? key) {
    final m = keyRe.firstMatch('${key ?? ''}');
    return m == null ? null : (m.group(1)!, int.parse(m.group(2)!));
  }

  /// The importer's key maps, by the map names the declaration gives each
  /// synced family. A family that syncs but whose map was not passed is a
  /// programming error, reported loudly rather than dropping rows — the
  /// port of EXE `entityKeyMaps`.
  static Map<String, Map<int, int>> keyMaps(Map<String, Map<int, int>> localMaps) {
    final out = <String, Map<int, int>>{};
    for (final f in entityFamilies) {
      final name = f.sync;
      if (name == null) continue;
      final m = localMaps[name];
      if (m == null) throw StateError('entityKeyMaps: no $name for ${f.prefix}_ keys');
      out[f.prefix] = m;
    }
    return out;
  }

  /// `module_12` → `module_57` through the maps; null when it cannot be
  /// mapped (a family that does not travel, or a row that did not come).
  static String? remap(Object? key, Map<String, Map<int, int>> maps) {
    final k = parse(key);
    if (k == null) return null;
    final mapped = maps[k.$1]?[k.$2];
    return mapped == null ? null : '${k.$1}_$mapped';
  }

  /// Every entity key living inside [moduleIds], by the `owner` facet — what
  /// the trash collects the relations of.
  static Future<Set<String>> keysOwnedBy(DatabaseExecutor db, Iterable<int> moduleIds) async {
    final out = <String>{};
    for (final f in entityFamilies) {
      final sql = f.owner;
      if (sql == null) continue;
      for (final mid in moduleIds) {
        for (final r in await db.rawQuery(sql, [mid])) {
          out.add('${f.prefix}_${r['id']}');
        }
      }
    }
    return out;
  }

  /// key → display name, by the `lookup` facet; null when the row is gone.
  static Future<String?> nameOf(DatabaseExecutor db, String key) async {
    final k = parse(key);
    final f = k == null ? null : byPrefix[k.$1];
    if (f == null) return null;
    final r = await db.rawQuery(f.lookupSql, [k!.$2]);
    return r.isEmpty ? null : r.first['name'] as String?;
  }
}

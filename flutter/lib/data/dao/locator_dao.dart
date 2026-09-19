import 'package:sqflite/sqflite.dart';
import '../models/locator_model.dart';

/// Data access for the Locator kind.
class LocatorDao {
  final Database db;
  LocatorDao(this.db);

  /// The module's map, created on first use. A Locator module owns exactly
  /// one map row (map.module_ref), which is the same row the desktop's
  /// getOrCreateModuleMap returns.
  Future<MapModel> ensureMap(int moduleRef) async {
    final rows = await db.query('map',
        where: 'module_ref=?', whereArgs: [moduleRef], orderBy: 'id', limit: 1);
    if (rows.isNotEmpty) return MapModel.fromMap(rows.first);
    final id = await db.insert('map', {'module_ref': moduleRef});
    return MapModel(id: id, moduleRef: moduleRef);
  }

  /// Areas with their vertices already attached. Two queries rather than one
  /// per area, since a map with many areas would otherwise fan out badly.
  Future<List<MapAreaModel>> getAreas(int mapId) async {
    final areaRows = await db.rawQuery('''
      SELECT ma.*, uc.color_code FROM map_area ma
      LEFT JOIN use_color uc ON ma.color = uc.id
      WHERE ma.map_id=? ORDER BY ma.id
    ''', [mapId]);
    if (areaRows.isEmpty) return const [];

    final pointRows = await db.rawQuery('''
      SELECT mp.* FROM map_point mp
      JOIN map_area ma ON mp.area_id = ma.id
      WHERE ma.map_id=? ORDER BY mp.area_id, mp.point_order, mp.id
    ''', [mapId]);

    final byArea = <int, List<MapPointModel>>{};
    for (final r in pointRows) {
      final p = MapPointModel.fromMap(r);
      (byArea[p.areaId] ??= []).add(p);
    }
    return areaRows
        .map((a) => MapAreaModel.fromMap(a, byArea[a['id'] as int] ?? const []))
        .toList();
  }

  Future<int> createArea({required int mapId, String? name}) async {
    return db.insert('map_area', {'map_id': mapId, 'area_name': name});
  }

  Future<void> renameArea(int id, String? name) async {
    await db.rawUpdate(
      "UPDATE map_area SET area_name=?,update_at=datetime('now') WHERE id=?",
      [name, id],
    );
  }

  /// map_point cascades on area_id, so the vertices go with the area.
  Future<void> deleteArea(int id) async {
    await db.delete('map_area', where: 'id=?', whereArgs: [id]);
  }

  /// Appends a vertex. Coordinates are written through unchanged — see the
  /// note in locator_model.dart on why they are never rescaled.
  Future<int> addPoint({
    required int areaId,
    required double x,
    required double y,
  }) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(point_order),-1)+1 AS next FROM map_point WHERE area_id=?',
      [areaId],
    );
    return db.insert('map_point', {
      'area_id': areaId,
      'point_order': Sqflite.firstIntValue(orderRows) ?? 0,
      'x': x,
      'y': y,
    });
  }

  Future<void> movePoint(int id, double x, double y) async {
    await db.rawUpdate(
      "UPDATE map_point SET x=?,y=?,update_at=datetime('now') WHERE id=?",
      [x, y, id],
    );
  }

  Future<void> deletePoint(int id) async {
    await db.delete('map_point', where: 'id=?', whereArgs: [id]);
  }

  /// Removes the most recently added vertex of an area, for undo while
  /// tracing. Ordered by point_order then id so it matches what was drawn
  /// last rather than whatever the row order happens to be.
  Future<int?> lastPointId(int areaId) async {
    final rows = await db.query('map_point',
        columns: ['id'], where: 'area_id=?', whereArgs: [areaId],
        orderBy: 'point_order DESC, id DESC', limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }
}

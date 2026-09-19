import 'package:sqflite/sqflite.dart';
import '../models/wanderer_model.dart';

/// Data access for the Wanderer kind: pins on a map, each optionally tied to
/// a timeline event.
class WandererDao {
  final Database db;
  WandererDao(this.db);

  /// The module's pins, with the linked event's name resolved. A LEFT JOIN
  /// rather than an inner one because event_ref is nullable and is also set
  /// to NULL when the event it pointed at is deleted — an unlinked pin must
  /// still come back.
  Future<List<MapEventModel>> getPins(int moduleRef) async {
    final rows = await db.rawQuery('''
      SELECT me.*, te.event_name AS event_name
        FROM map_event me
        LEFT JOIN timeline_event te ON me.event_ref = te.id
       WHERE me.module_ref = ? ORDER BY me.id
    ''', [moduleRef]);
    return rows.map(MapEventModel.fromMap).toList();
  }

  /// Every timeline event in the Nexus, for the link picker. Ordered
  /// chronologically over the joined date, the same way Chronicler orders
  /// its own list, so the picker reads like the timeline it comes from.
  Future<List<LinkableEvent>> listNexusEvents(int nexusId) async {
    final rows = await db.rawQuery('''
      SELECT te.id, te.event_name, m.name AS module_name
        FROM timeline_event te
        JOIN timeline t ON te.timeline_id = t.id
        JOIN module m ON t.module_ref = m.id
        JOIN timeline_date s ON te.start_at = s.id
       WHERE m.nexus_ref = ?
       ORDER BY s.years, s.month, s.day, s.hour, s.minute, te.id
    ''', [nexusId]);
    return rows.map(LinkableEvent.fromMap).toList();
  }

  Future<int> createPin({
    required int moduleRef,
    required double x,
    required double y,
    String? label,
    int? eventRef,
  }) async {
    return db.insert('map_event', {
      'module_ref': moduleRef,
      'x': x,
      'y': y,
      'label': label,
      'event_ref': eventRef,
    });
  }

  /// Label and link together, since the edit sheet sets both at once.
  /// Passing a null eventRef clears the link, which is a real action here
  /// rather than "leave unchanged".
  Future<void> updatePin(int id, {String? label, int? eventRef}) async {
    await db.rawUpdate(
      "UPDATE map_event SET label=?,event_ref=?,update_at=datetime('now') WHERE id=?",
      [label, eventRef, id],
    );
  }

  /// Position only — called on drag end, so it cannot clobber a label or
  /// link edited meanwhile.
  Future<void> movePin(int id, double x, double y) async {
    await db.rawUpdate(
      "UPDATE map_event SET x=?,y=?,update_at=datetime('now') WHERE id=?",
      [x, y, id],
    );
  }

  Future<void> deletePin(int id) async {
    await db.delete('map_event', where: 'id=?', whereArgs: [id]);
  }
}

import 'package:sqflite/sqflite.dart';

import '../../core/calendar/calendar_engine.dart';
import '../services/wiki_service.dart';
import '../models/chronicler_model.dart';
import 'page_block_dao.dart';

/// Data access for the Chronicler kind: one timeline per module, and the
/// dated events on it.
class ChroniclerDao {
  final Database db;
  ChroniclerDao(this.db);

  /// The module's calendar (module_ui.calendarConfig, authored on the
  /// desktop), or the international one when it has none.
  Future<CalSpec> getCalendar(int moduleRef) async {
    final r = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='calendarConfig'", [moduleRef]);
    return calSpecNormalize(r.isEmpty ? null : r.first['ui_value']);
  }

  /// The module's timeline, created on first use. A module has at most one;
  /// `timeline.module_ref` is what ties it to the module, and the Electron
  /// side reads the same row.
  Future<int> ensureTimeline(int moduleRef) async {
    final rows = await db.query(
      'timeline',
      columns: ['id'],
      where: 'module_ref=?',
      whereArgs: [moduleRef],
      orderBy: 'id',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('timeline', {'module_ref': moduleRef});
  }

  /// timeline_date is shared vault-wide and deduplicated by its UNIQUE
  /// (day,month,years,hour,minute), so this looks up before inserting and
  /// falls back to the lookup if a concurrent insert won the race.
  Future<int> ensureDate({
    required int day,
    required int month,
    required int years,
    int hour = 0,
    int minute = 0,
  }) async {
    Future<int?> find() async {
      final rows = await db.query(
        'timeline_date',
        columns: ['id'],
        where: 'day=? AND month=? AND years=? AND hour=? AND minute=?',
        whereArgs: [day, month, years, hour, minute],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final existing = await find();
    if (existing != null) return existing;
    try {
      return await db.insert('timeline_date', {
        'day': day, 'month': month, 'years': years, 'hour': hour, 'minute': minute,
      });
    } on DatabaseException {
      final raced = await find();
      if (raced != null) return raced;
      rethrow;
    }
  }

  static const _selectEvent = '''
    SELECT te.id, te.timeline_id, te.event_name, te.story, uc.color_code,
           s.id AS s_id, s.day AS s_day, s.month AS s_month, s.years AS s_years,
           s.hour AS s_hour, s.minute AS s_minute,
           e.id AS e_id, e.day AS e_day, e.month AS e_month, e.years AS e_years,
           e.hour AS e_hour, e.minute AS e_minute
    FROM timeline_event te
    JOIN timeline_date s ON te.start_at = s.id
    LEFT JOIN timeline_date e ON te.end_at = e.id
    LEFT JOIN use_color uc ON te.color = uc.id
  ''';

  /// Chronological order comes from the joined date, not insertion order.
  Future<List<TimelineEventModel>> getEvents(int timelineId) async {
    final rows = await db.rawQuery(
      '$_selectEvent WHERE te.timeline_id=? '
      'ORDER BY s.years, s.month, s.day, s.hour, s.minute, te.id',
      [timelineId],
    );
    return rows.map(TimelineEventModel.fromJoin).toList();
  }

  Future<int> createEvent({
    required int timelineId,
    required int startDateId,
    String? name,
    String? story,
    int? endDateId,
  }) async {
    return db.insert('timeline_event', {
      'timeline_id': timelineId,
      'start_at': startDateId,
      'end_at': endDateId,
      'event_name': name,
      'story': story,
    });
  }

  Future<void> updateEvent(
    int id, {
    required int startDateId,
    String? name,
    String? story,
    int? endDateId,
  }) async {
    await db.rawUpdate(
      "UPDATE timeline_event SET event_name=?,story=?,start_at=?,end_at=?,"
      "update_at=datetime('now') WHERE id=?",
      [name, story, startDateId, endDateId, id],
    );
    await WikiService.reindexSource(db, 'tlev', id);
  }

  Future<void> deleteEvent(int id) async {
    await PageBlockDao(db).clearItem('tlev_$id'); // its page goes with it (EXE clearItemBlocks)
    await db.delete('timeline_event', where: 'id=?', whereArgs: [id]);
  }
}

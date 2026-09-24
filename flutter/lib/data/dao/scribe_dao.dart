import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';
import '../models/scribe_model.dart';
import 'page_block_dao.dart';

/// Data access for the Scribe kind: chat-style notes. A module owns sessions
/// (`chat_session`); a session owns messages (`chat_message`). Both cascade
/// on delete, so removing a module takes its whole transcript with it.
class ScribeDao {
  final Database db;
  ScribeDao(this.db);

  Future<List<ChatSessionModel>> getSessions(int moduleRef) async {
    final rows = await db.rawQuery(
      'SELECT * FROM chat_session WHERE module_ref=? ORDER BY session_order, id',
      [moduleRef],
    );
    return rows.map(ChatSessionModel.fromMap).toList();
  }

  Future<int> createSession({required int moduleRef, required String name}) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(session_order),-1)+1 AS next FROM chat_session WHERE module_ref=?',
      [moduleRef],
    );
    final nextOrder = Sqflite.firstIntValue(orderRows) ?? 0;
    final id = await db.insert('chat_session', {
      'module_ref': moduleRef,
      'name': name,
      'session_order': nextOrder,
    });
    await WikiService.resolveDangling(db, name, await WikiService.nexusOfModule(db, moduleRef));
    return id;
  }

  Future<void> renameSession(int id, String name) async {
    final old = await db.rawQuery(
        'SELECT s.name, m.nexus_ref FROM chat_session s JOIN module m ON s.module_ref=m.id WHERE s.id=?', [id]);
    await db.rawUpdate(
      "UPDATE chat_session SET name=?,update_at=datetime('now') WHERE id=?",
      [name, id],
    );
    if (old.isNotEmpty) {
      await WikiService.renamed(db, 'chss_$id', old.first['name'] as String?, name, old.first['nexus_ref'] as int?);
    }
  }

  Future<void> deleteSession(int id) async {
    await PageBlockDao(db).clearItem('chss_$id'); // its page goes with it (EXE clearItemBlocks)
    await db.delete('chat_session', where: 'id=?', whereArgs: [id]);
  }

  /// Messages oldest-first. The colour is resolved here rather than in the
  /// widget so the transcript renders in one query instead of one per bubble.
  Future<List<ChatMessageModel>> getMessages(int sessionRef) async {
    final rows = await db.rawQuery('''
      SELECT cm.*, uc.color_code FROM chat_message cm
      LEFT JOIN use_color uc ON cm.color=uc.id
      WHERE cm.session_ref=? ORDER BY cm.id
    ''', [sessionRef]);
    return rows.map(ChatMessageModel.fromMap).toList();
  }

  Future<int> addMessage({
    required int sessionRef,
    required String message,
    String side = 'r',
    int? colorId,
  }) async {
    final id = await db.insert('chat_message', {
      'session_ref': sessionRef,
      'message': message,
      'side': side,
      'color': colorId,
    });
    // Keep the owning session's timestamp current so a session list ordered
    // by recency is not stuck at creation time.
    await db.rawUpdate(
      "UPDATE chat_session SET update_at=datetime('now') WHERE id=?",
      [sessionRef],
    );
    await WikiService.reindexSource(db, 'chss', sessionRef);
    return id;
  }

  Future<void> updateMessage(int id, String message) async {
    await db.rawUpdate('UPDATE chat_message SET message=? WHERE id=?', [message, id]);
    final s = await db.rawQuery('SELECT session_ref FROM chat_message WHERE id=?', [id]);
    if (s.isNotEmpty) await WikiService.reindexSource(db, 'chss', s.first['session_ref'] as int);
  }

  Future<void> deleteMessage(int id) async {
    await db.delete('chat_message', where: 'id=?', whereArgs: [id]);
  }
}

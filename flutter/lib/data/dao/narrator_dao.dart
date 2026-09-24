import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';
import '../models/narrator_model.dart';

/// Data access for the Narrator kind.
class NarratorDao {
  final Database db;
  NarratorDao(this.db);

  // ---- scenes -------------------------------------------------------------

  Future<List<DialogueModel>> getDialogues(int moduleRef) async {
    final rows = await db.rawQuery('''
      SELECT sd.*, uc.color_code FROM story_dialogue sd
      LEFT JOIN use_color uc ON sd.color = uc.id
      WHERE sd.module_ref=? ORDER BY sd.id
    ''', [moduleRef]);
    return rows.map(DialogueModel.fromMap).toList();
  }

  /// pos_x/pos_y are left at their column defaults; the desktop board places
  /// a new node itself, and guessing coordinates here would scatter nodes.
  Future<int> createDialogue({required int moduleRef, required String name}) async {
    return db.insert('story_dialogue', {'module_ref': moduleRef, 'name': name});
  }

  Future<void> updateDialogue(int id, {required String name, String? description}) async {
    await db.rawUpdate(
      "UPDATE story_dialogue SET name=?,description=?,update_at=datetime('now') WHERE id=?",
      [name, description, id],
    );
    await WikiService.reindexSource(db, 'sdlg', id);
  }

  Future<void> deleteDialogue(int id) async {
    await db.delete('story_dialogue', where: 'id=?', whereArgs: [id]);
  }

  // ---- script -------------------------------------------------------------

  Future<List<TalkModel>> getTalks(int dialogueRef) async {
    final rows = await db.rawQuery(
      'SELECT * FROM story_talk WHERE dialogue_ref=? ORDER BY talk_order, id',
      [dialogueRef],
    );
    return rows.map(TalkModel.fromMap).toList();
  }

  Future<int> addTalk({
    required int dialogueRef,
    String? speaker,
    String? sentence,
  }) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(talk_order),-1)+1 AS next FROM story_talk WHERE dialogue_ref=?',
      [dialogueRef],
    );
    return db.insert('story_talk', {
      'dialogue_ref': dialogueRef,
      'speaker': speaker,
      'talk_sentence': sentence,
      'row_type': 'talk',
      'talk_order': Sqflite.firstIntValue(orderRows) ?? 0,
    });
  }

  Future<void> updateTalk(int id, {String? speaker, String? sentence}) async {
    await db.rawUpdate(
      "UPDATE story_talk SET speaker=?,talk_sentence=?,update_at=datetime('now') WHERE id=?",
      [speaker, sentence, id],
    );
  }

  Future<void> deleteTalk(int id) async {
    await db.delete('story_talk', where: 'id=?', whereArgs: [id]);
  }

  // ---- routes -------------------------------------------------------------

  /// Outgoing routes from one scene, with the destination's name resolved.
  Future<List<StoryEdgeModel>> getEdgesFrom(int dialogueRef) async {
    final rows = await db.rawQuery('''
      SELECT se.*, d.name AS to_name FROM story_edge se
      JOIN story_dialogue d ON se.to_ref = d.id
      WHERE se.from_ref=? ORDER BY se.id
    ''', [dialogueRef]);
    return rows.map(StoryEdgeModel.fromMap).toList();
  }

  /// UNIQUE(from_ref, to_ref) means adding the same route twice is a no-op
  /// rather than an error the caller has to special-case.
  Future<void> addEdge({
    required int moduleRef,
    required int fromRef,
    required int toRef,
    String? label,
  }) async {
    await db.insert(
      'story_edge',
      {'module_ref': moduleRef, 'from_ref': fromRef, 'to_ref': toRef, 'label': label},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteEdge(int id) async {
    await db.delete('story_edge', where: 'id=?', whereArgs: [id]);
  }
}

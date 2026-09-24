import 'package:sqflite/sqflite.dart';
import '../models/hashtag_model.dart';

class HashtagDao {
  final Database db;
  HashtagDao(this.db);

  Future<List<HashtagModel>> getHashtags() async {
    final rows = await db.rawQuery('''
      SELECT h.*, uc.color_code FROM hashtag h
      LEFT JOIN use_color uc ON h.tag_color=uc.id ORDER BY h.tag_name
    ''');
    return rows.map(HashtagModel.fromMap).toList();
  }

  Future<int> createHashtag(String name, int? colorId) async {
    return db.insert('hashtag', {'tag_name': name, 'tag_color': colorId});
  }

  Future<void> updateHashtag(int id, String name, int? colorId) async {
    await db.rawUpdate(
      "UPDATE hashtag SET tag_name=?,tag_color=?,update_at=datetime('now') WHERE id=?",
      [name, colorId, id],
    );
  }

  Future<void> deleteHashtag(int id) async {
    await db.delete('hashtag', where: 'id=?', whereArgs: [id]);
  }

  /// The tags on one module (module_hashtag).
  Future<List<HashtagModel>> getModuleTags(int moduleId) async {
    final rows = await db.rawQuery('''
      SELECT h.*, uc.color_code FROM module_hashtag mh JOIN hashtag h ON mh.hashtag_id=h.id
      LEFT JOIN use_color uc ON h.tag_color=uc.id WHERE mh.module_ref=? ORDER BY h.tag_name
    ''', [moduleId]);
    return rows.map(HashtagModel.fromMap).toList();
  }

  Future<void> setModuleTag(int moduleId, int hashtagId, bool on) async {
    if (on) {
      await db.rawInsert('INSERT OR IGNORE INTO module_hashtag (module_ref, hashtag_id) VALUES (?,?)', [moduleId, hashtagId]);
    } else {
      await db.rawDelete('DELETE FROM module_hashtag WHERE module_ref=? AND hashtag_id=?', [moduleId, hashtagId]);
    }
  }
}

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
}

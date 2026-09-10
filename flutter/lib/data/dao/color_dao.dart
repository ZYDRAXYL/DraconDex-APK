import 'package:sqflite/sqflite.dart';
import '../models/color_model.dart';

class ColorDao {
  final Database db;
  ColorDao(this.db);

  Future<List<ColorModel>> getColors() async {
    final rows = await db.rawQuery('SELECT * FROM use_color ORDER BY id');
    return rows.map(ColorModel.fromMap).toList();
  }

  Future<List<ColorModel>> getRecentColors() async {
    final rows = await db.rawQuery('SELECT * FROM use_color ORDER BY update_at DESC LIMIT 10');
    return rows.map(ColorModel.fromMap).toList();
  }

  Future<void> addColor(String code) async {
    await db.execute('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
  }

  Future<void> markColorUsed(int id) async {
    await db.execute("UPDATE use_color SET update_at=datetime('now') WHERE id=?", [id]);
  }

  Future<bool> deleteColor(int id) async {
    final rows = await db.rawQuery('''
      SELECT 1 FROM (
        SELECT project_color FROM project WHERE project_color=?
        UNION ALL SELECT folder_color FROM project_folder WHERE folder_color=?
        UNION ALL SELECT color FROM object_category WHERE color=?
        UNION ALL SELECT color FROM object WHERE color=?
        UNION ALL SELECT color FROM timeline WHERE color=?
        UNION ALL SELECT color FROM timeline_event WHERE color=?
        UNION ALL SELECT color FROM relation WHERE color=?
        UNION ALL SELECT tag_color FROM hashtag WHERE tag_color=?
        UNION ALL SELECT color FROM nexus WHERE color=?
        UNION ALL SELECT color FROM module WHERE color=?
        UNION ALL SELECT icon_color FROM module WHERE icon_color=?
      ) LIMIT 1
    ''', [id, id, id, id, id, id, id, id, id, id, id]);
    if (rows.isNotEmpty) return false;
    await db.delete('use_color', where: 'id=?', whereArgs: [id]);
    return true;
  }
}

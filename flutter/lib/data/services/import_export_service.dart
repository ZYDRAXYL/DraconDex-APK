import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';

class ImportSummary {
  final int colors, folders, projects, categories, templates, objects;
  final int timelines, events, hashtags, descriptions, mappings;

  const ImportSummary({
    this.colors = 0, this.folders = 0, this.projects = 0, this.categories = 0,
    this.templates = 0, this.objects = 0, this.timelines = 0, this.events = 0,
    this.hashtags = 0, this.descriptions = 0, this.mappings = 0,
  });

  @override
  String toString() =>
      'Projects: $projects, Objects: $objects, Timelines: $timelines, Events: $events, '
      'Hashtags: $hashtags, Colors: $colors';
}

class ImportExportService {
  static Future<String> exportToShare() async {
    return DatabaseHelper.instance.exportToTemp();
  }

  static Future<ImportSummary> importFromFile(String sourcePath) async {
    final source = await openReadOnlyDatabase(sourcePath);
    final target = await DatabaseHelper.instance.database;

    int colors = 0, folders = 0, projects = 0, categories = 0, templates = 0;
    int objects = 0, timelines = 0, events = 0, hashtags = 0, descriptions = 0;
    int mappings = 0;

    Future<bool> hasTable(Database db, String name) async {
      final r = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [name]);
      return r.isNotEmpty;
    }

    Future<bool> hasColumn(Database db, String table, String col) async {
      final r = await db.rawQuery('PRAGMA table_info($table)');
      return r.any((c) => c['name'] == col);
    }

    await target.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');

      // Build source color map: id -> color_code
      final colorMap = <int, String>{};
      if (await hasTable(source, 'use_color')) {
        final rows = await source.rawQuery('SELECT id, color_code FROM use_color');
        for (final r in rows) {
          if (r['color_code'] != null) colorMap[r['id'] as int] = r['color_code'] as String;
        }
        for (final code in colorMap.values) {
          final n = await txn.rawInsert('INSERT OR IGNORE INTO use_color (color_code) VALUES (?)', [code]);
          if (n > 0) colors++;
        }
      }

      // Folders
      final srcFolderNameById = <int, String>{};
      if (await hasTable(source, 'project_folder')) {
        final rows = await source.rawQuery('SELECT id, name, folder_memo, folder_color FROM project_folder WHERE name IS NOT NULL');
        for (final r in rows) {
          srcFolderNameById[r['id'] as int] = r['name'] as String;
          final colorCode = colorMap[r['folder_color'] as int?];
          final n = await txn.rawInsert(
            'INSERT OR IGNORE INTO project_folder (name,folder_memo,folder_color) VALUES (?,?,(SELECT id FROM use_color WHERE color_code=?))',
            [r['name'], r['folder_memo'], colorCode],
          );
          if (n > 0) folders++;
        }
      }

      // Build project key map: src id -> semantic key
      final projKeyMap = <int, String>{};
      if (await hasTable(source, 'project')) {
        final srcProjs = await source.rawQuery('SELECT id, codename, name FROM project');
        for (final p in srcProjs) {
          final id = p['id'] as int;
          final code = p['codename'] as String?;
          final nm = p['name'] as String;
          projKeyMap[id] = code != null ? 'code:$code' : 'name:$nm';
        }

        // Insert missing projects
        for (final r in await source.rawQuery('SELECT codename, name, project_memo, folder_id, project_color FROM project WHERE name IS NOT NULL')) {
          final code = r['codename'] as String?;
          final nm = r['name'] as String;
          List<Map<String, Object?>> existing;
          if (code != null) {
            existing = await txn.rawQuery('SELECT id FROM project WHERE codename=?', [code]);
          } else {
            existing = await txn.rawQuery('SELECT id FROM project WHERE codename IS NULL AND name=?', [nm]);
          }
          if (existing.isNotEmpty) continue;
          final folderName = srcFolderNameById[r['folder_id'] as int?];
          final colorCode = colorMap[r['project_color'] as int?];
          await txn.rawInsert(
            'INSERT INTO project (codename,name,project_memo,folder_id,project_color) VALUES (?,?,?,'
            '(SELECT id FROM project_folder WHERE name=?),'
            '(SELECT id FROM use_color WHERE color_code=?))',
            [code, nm, r['project_memo'], folderName, colorCode],
          );
          projects++;
        }
      }

      Future<int?> targetProjId(String key) async {
        List<Map<String, Object?>> rows;
        if (key.startsWith('code:')) {
          rows = await txn.rawQuery('SELECT id FROM project WHERE codename=?', [key.substring(5)]);
        } else {
          rows = await txn.rawQuery('SELECT id FROM project WHERE codename IS NULL AND name=?', [key.substring(5)]);
        }
        return rows.isEmpty ? null : rows.first['id'] as int;
      }

      // Project descriptions
      if (await hasTable(source, 'project_description')) {
        for (final r in await source.rawQuery('SELECT project_id, attribute_name, attribute_text FROM project_description')) {
          final pKey = projKeyMap[r['project_id'] as int];
          if (pKey == null) continue;
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final exists = (await txn.rawQuery(
            'SELECT 1 FROM project_description WHERE project_id=? AND attribute_name IS ? AND attribute_text IS ?',
            [pid, r['attribute_name'], r['attribute_text']],
          )).isNotEmpty;
          if (exists) continue;
          await txn.rawInsert('INSERT INTO project_description (project_id,attribute_name,attribute_text) VALUES (?,?,?)', [pid, r['attribute_name'], r['attribute_text']]);
          descriptions++;
        }
      }

      // Category map: src id -> "projkey::catname"
      final catKeyMap = <int, String>{};
      if (await hasTable(source, 'object_category')) {
        final srcCats = await source.rawQuery('SELECT id, category_name, project_id, color FROM object_category');
        for (final c in srcCats) {
          final pKey = projKeyMap[c['project_id'] as int];
          if (pKey == null) continue;
          catKeyMap[c['id'] as int] = '$pKey::${c['category_name']}';
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final colorCode = colorMap[c['color'] as int?];
          final n = await txn.rawInsert(
            'INSERT OR IGNORE INTO object_category (category_name,project_id,color) VALUES (?,?,(SELECT id FROM use_color WHERE color_code=?))',
            [c['category_name'], pid, colorCode],
          );
          if (n > 0) categories++;
        }
      }

      Future<int?> targetCatId(String key) async {
        final idx = key.indexOf('::');
        if (idx < 0) return null;
        final pKey = key.substring(0, idx);
        final catName = key.substring(idx + 2);
        final pid = await targetProjId(pKey);
        if (pid == null) return null;
        final rows = await txn.rawQuery('SELECT id FROM object_category WHERE project_id=? AND category_name=?', [pid, catName]);
        return rows.isEmpty ? null : rows.first['id'] as int;
      }

      // Templates
      final tplKeyMap = <int, String>{}; // src id -> "catkey::desc::type"
      if (await hasTable(source, 'object_template')) {
        final hasType = await hasColumn(source, 'object_template', 'attribute_type');
        final tplSql = hasType
            ? "SELECT id,category_id,description,COALESCE(attribute_type,'text') attribute_type FROM object_template"
            : "SELECT id,category_id,description,'text' AS attribute_type FROM object_template";
        for (final t in await source.rawQuery(tplSql)) {
          final catKey = catKeyMap[t['category_id'] as int];
          if (catKey == null) continue;
          final desc = t['description'] as String;
          final atype = t['attribute_type'] as String;
          tplKeyMap[t['id'] as int] = '$catKey::$desc::$atype';
          final cid = await targetCatId(catKey);
          if (cid == null) continue;
          final exists = (await txn.rawQuery(
            "SELECT 1 FROM object_template WHERE category_id=? AND description=? AND COALESCE(attribute_type,'text')=?",
            [cid, desc, atype],
          )).isNotEmpty;
          if (exists) continue;
          await txn.rawInsert('INSERT INTO object_template (category_id,description,attribute_type) VALUES (?,?,?)', [cid, desc, atype]);
          templates++;
        }
      }

      // Objects
      final objKeyMap = <int, String>{}; // src id -> "catkey::name"
      if (await hasTable(source, 'object')) {
        final hasNote = await hasColumn(source, 'object', 'note');
        final noteSql = hasNote ? 'note' : 'NULL AS note';
        for (final o in await source.rawQuery('SELECT id, name, project_id, category_id, color, $noteSql FROM object')) {
          final catKey = catKeyMap[o['category_id'] as int];
          if (catKey == null) continue;
          final nm = o['name'] as String;
          objKeyMap[o['id'] as int] = '$catKey::$nm';
          final cid = await targetCatId(catKey);
          if (cid == null) continue;
          final pKey = projKeyMap[o['project_id'] as int];
          if (pKey == null) continue;
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final exists = (await txn.rawQuery('SELECT 1 FROM object WHERE name=? AND project_id=? AND category_id=?', [nm, pid, cid])).isNotEmpty;
          if (exists) continue;
          final colorCode = colorMap[o['color'] as int?];
          await txn.rawInsert(
            'INSERT INTO object (name,project_id,category_id,color,note) VALUES (?,?,?,(SELECT id FROM use_color WHERE color_code=?),?)',
            [nm, pid, cid, colorCode, o['note']],
          );
          objects++;
        }
      }

      // Object attributes
      if (await hasTable(source, 'object_attribute')) {
        for (final a in await source.rawQuery('SELECT object_id, template_id, attribute_value FROM object_attribute')) {
          final objKey = objKeyMap[a['object_id'] as int];
          final tplKey = tplKeyMap[a['template_id'] as int];
          if (objKey == null || tplKey == null) continue;
          // catkey is everything before the last "::<name>" in objKey
          final lastSep = objKey.lastIndexOf('::');
          if (lastSep < 0) continue;
          final catKey = objKey.substring(0, lastSep);
          final objName = objKey.substring(lastSep + 2);
          // ensure tpl also belongs to same catKey
          if (!tplKey.startsWith('$catKey::')) continue;
          final cid = await targetCatId(catKey);
          if (cid == null) continue;
          final pKey = catKey.substring(0, catKey.indexOf('::'));
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final oRows = await txn.rawQuery('SELECT id FROM object WHERE name=? AND project_id=? AND category_id=?', [objName, pid, cid]);
          if (oRows.isEmpty) continue;
          final oid = oRows.first['id'] as int;
          // tplKey = catkey::desc::type
          final tplRest = tplKey.substring(catKey.length + 2);
          final lastTplSep = tplRest.lastIndexOf('::');
          if (lastTplSep < 0) continue;
          final tplDesc = tplRest.substring(0, lastTplSep);
          final tplType = tplRest.substring(lastTplSep + 2);
          final tRows = await txn.rawQuery(
            "SELECT id FROM object_template WHERE category_id=? AND description=? AND COALESCE(attribute_type,'text')=?",
            [cid, tplDesc, tplType],
          );
          if (tRows.isEmpty) continue;
          final tid = tRows.first['id'] as int;
          await txn.rawInsert('INSERT OR IGNORE INTO object_attribute (object_id,template_id,attribute_value) VALUES (?,?,?)', [oid, tid, a['attribute_value']]);
          mappings++;
        }
      }

      // Timelines
      final tlKeyMap = <int, String>{}; // src id -> "projkey::linename"
      if (await hasTable(source, 'timeline')) {
        for (final t in await source.rawQuery('SELECT id, line_name, project_id, color FROM timeline')) {
          final pKey = projKeyMap[t['project_id'] as int];
          if (pKey == null) continue;
          tlKeyMap[t['id'] as int] = '$pKey::${t['line_name'] ?? ''}';
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final lineName = t['line_name'];
          final exists = (await txn.rawQuery('SELECT 1 FROM timeline WHERE project_id=? AND line_name IS ?', [pid, lineName])).isNotEmpty;
          if (exists) continue;
          final colorCode = colorMap[t['color'] as int?];
          await txn.rawInsert(
            'INSERT INTO timeline (line_name,project_id,color) VALUES (?,(SELECT id FROM project WHERE id=?),(SELECT id FROM use_color WHERE color_code=?))',
            [lineName, pid, colorCode],
          );
          timelines++;
        }
      }

      // Timeline dates
      if (await hasTable(source, 'timeline_date')) {
        for (final d in await source.rawQuery('SELECT day,month,years,COALESCE(hour,0) hour,COALESCE(minute,0) minute FROM timeline_date')) {
          await txn.rawInsert('INSERT OR IGNORE INTO timeline_date (day,month,years,hour,minute) VALUES (?,?,?,?,?)', [d['day'], d['month'], d['years'], d['hour'], d['minute']]);
        }
      }

      // Timeline events
      if (await hasTable(source, 'timeline_event')) {
        final srcDates = await source.rawQuery('SELECT id,day,month,years,COALESCE(hour,0) hour,COALESCE(minute,0) minute FROM timeline_date');
        final dateMap = <int, Map<String, Object?>>{};
        for (final d in srcDates) {
          dateMap[d['id'] as int] = d;
        }

        Future<int> getOrCreateDate(Map<String, Object?> d) async {
          await txn.rawInsert('INSERT OR IGNORE INTO timeline_date (day,month,years,hour,minute) VALUES (?,?,?,?,?)', [d['day'], d['month'], d['years'], d['hour'], d['minute']]);
          final rows = await txn.rawQuery('SELECT id FROM timeline_date WHERE day=? AND month=? AND years=? AND hour=? AND minute=?', [d['day'], d['month'], d['years'], d['hour'], d['minute']]);
          return rows.first['id'] as int;
        }

        final hasStory = await hasColumn(source, 'timeline_event', 'story');
        final hasEndAt = await hasColumn(source, 'timeline_event', 'end_at');
        final storyCol = hasStory ? 'story' : 'NULL AS story';
        final endCol = hasEndAt ? 'end_at' : 'NULL AS end_at';

        for (final ev in await source.rawQuery('SELECT timeline_id, event_name, start_at, $endCol, color, $storyCol FROM timeline_event')) {
          final tlKey = tlKeyMap[ev['timeline_id'] as int];
          final sDate = dateMap[ev['start_at'] as int?];
          if (tlKey == null || sDate == null) continue;
          final tlSep = tlKey.indexOf('::');
          if (tlSep < 0) continue;
          final pKey = tlKey.substring(0, tlSep);
          final lineName = tlKey.substring(tlSep + 2);
          final pid = await targetProjId(pKey);
          if (pid == null) continue;
          final tlRows = await txn.rawQuery('SELECT id FROM timeline WHERE project_id=? AND line_name IS ?', [pid, lineName.isEmpty ? null : lineName]);
          if (tlRows.isEmpty) continue;
          final tlId = tlRows.first['id'] as int;

          final sId = await getOrCreateDate(sDate);
          int? eId;
          final endAt = ev['end_at'];
          if (endAt != null && dateMap.containsKey(endAt as int)) {
            eId = await getOrCreateDate(dateMap[endAt]!);
          }
          final evName = ev['event_name'];
          final exists = (await txn.rawQuery(
            "SELECT 1 FROM timeline_event WHERE timeline_id=? AND COALESCE(event_name,'')=COALESCE(?,'') AND start_at=? AND COALESCE(end_at,0)=COALESCE(?,0)",
            [tlId, evName, sId, eId],
          )).isNotEmpty;
          if (exists) continue;
          final colorCode = colorMap[ev['color'] as int?];
          await txn.rawInsert(
            'INSERT INTO timeline_event (timeline_id,event_name,start_at,end_at,color,story) VALUES (?,?,?,?,(SELECT id FROM use_color WHERE color_code=?),?)',
            [tlId, evName, sId, eId, colorCode, ev['story']],
          );
          events++;
        }
      }

      // Hashtags
      if (await hasTable(source, 'hashtag')) {
        final hasTagColor = await hasColumn(source, 'hashtag', 'tag_color');
        final tagColorCol = hasTagColor ? 'tag_color' : 'NULL AS tag_color';
        for (final h in await source.rawQuery('SELECT tag_name, $tagColorCol FROM hashtag')) {
          final colorCode = colorMap[h['tag_color'] as int?];
          final n = await txn.rawInsert(
            'INSERT OR IGNORE INTO hashtag (tag_name,tag_color) VALUES (?,(SELECT id FROM use_color WHERE color_code=?))',
            [h['tag_name'], colorCode],
          );
          if (n > 0) hashtags++;
        }
      }

      await txn.execute('PRAGMA foreign_keys = ON');
    });

    await source.close();

    return ImportSummary(
      colors: colors, folders: folders, projects: projects, categories: categories,
      templates: templates, objects: objects, timelines: timelines, events: events,
      hashtags: hashtags, descriptions: descriptions, mappings: mappings,
    );
  }
}

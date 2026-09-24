import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';
import '../models/recent_view_model.dart';
import 'legacy_notes.dart';

/// Where an entity key opens in this app: a module's page, or an element
/// page inside its module (APP docs/APK-V3.md §10.3). The port of what EXE's
/// `openEntityByKey` decides. Null when the key names nothing that has a
/// page here (an asset, a legacy key, a row that is gone).
class EntityLocation {
  static const _owner = <String, String>{
    'module': 'SELECT id AS m, nexus_ref AS n FROM module WHERE id=?',
    'cobj': 'SELECT m.id AS m, m.nexus_ref AS n FROM classifier_object x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'bchp': 'SELECT m.id AS m, m.nexus_ref AS n FROM book_chapter x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'chss': 'SELECT m.id AS m, m.nexus_ref AS n FROM chat_session x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'sdlg': 'SELECT m.id AS m, m.nexus_ref AS n FROM story_dialogue x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'skpg': 'SELECT m.id AS m, m.nexus_ref AS n FROM sketch_page x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'divt': 'SELECT m.id AS m, m.nexus_ref AS n FROM diviner_table x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'exn': 'SELECT m.id AS m, m.nexus_ref AS n FROM exhibit_node x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'mevt': 'SELECT m.id AS m, m.nexus_ref AS n FROM map_event x JOIN module m ON x.module_ref=m.id WHERE x.id=?',
    'tlev': 'SELECT m.id AS m, m.nexus_ref AS n FROM timeline_event x JOIN timeline t ON x.timeline_id=t.id '
        'JOIN module m ON t.module_ref=m.id WHERE x.id=?',
  };

  /// An element whose page opens as the element itself; anything else in a
  /// module (an event, a node) opens its module, as on the desktop.
  static const _elementPages = {'cobj', 'bchp', 'chss', 'sdlg', 'skpg', 'divt', 'mevt'};

  static Future<String?> of(DatabaseExecutor db, String key) async {
    final k = EntityKinds.parse(key);
    if (k == null) return null;
    var (prefix, id) = k;
    if (prefix == 'note') {
      // A converted note opens the module it became.
      final mid = await LegacyNotes.moduleOfNote(db, id);
      if (mid == null) return null;
      prefix = 'module';
      id = mid;
    }
    if (prefix == 'file') {
      // An asset has no page; its link opens the Nexus's Asset Nest.
      final r = await db.rawQuery('SELECT nexus_ref FROM import_file WHERE id=?', [id]);
      return r.isEmpty ? null : '/assets/${r.first['nexus_ref']}';
    }
    final sql = _owner[prefix];
    if (sql == null) return null;
    final r = await db.rawQuery(sql, [id]);
    if (r.isEmpty) return null;
    final nexus = r.first['n'] as int;
    final module = r.first['m'] as int;
    if (prefix == 'module') return RecentView.locationFor(nexus, module);
    return RecentView.locationFor(nexus, module, _elementPages.contains(prefix) ? '${prefix}_$id' : null);
  }
}

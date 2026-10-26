import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/author_dao.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/narrator_dao.dart';
import 'package:dracondex/data/dao/wanderer_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/entity_location.dart';
import 'package:dracondex/data/services/legacy_notes.dart';
import 'package:dracondex/data/services/wiki_service.dart';
import 'package:dracondex/widgets/wiki_field.dart';

/// The wiki-link system, ported from EXE db/wiki.js (APP docs/APK-V3.md §6):
/// the same regex, the same resolver order, and a rename that follows the
/// links typed against the old name.
void main() {
  sqfliteFfiInit();

  Future<Database> openVault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return db;
  }

  test('parse finds names, aliases and namespaces, and skips empties', () {
    final l = WikiService.parse('See [[Aria]], [[file:map.png|the map]] and [[ ]] but not [single].');
    expect(l.map((m) => m.name), ['Aria', 'file:map.png']);
    expect(l[1].label, 'the map');
    expect(WikiService.parse('[[note:Old]]').single.label, 'Old');
  });

  test('Procress 27: a link reads as its name — alias, else the object, else the name', () {
    expect(WikiService.displayText('see [[obj:Characters/Aria]] and [[Harbor|the port]] or [[Mira]]'),
        'see Aria and the port or Mira');
    expect(WikiService.displayText('no links'), 'no links');
    expect(WikiService.displayParts('a [[obj:M/"HP/MP"]]'), [('a ', false), ('HP/MP', true)]);
  });

  test('resolution order: a module beats an object of the same name; ns: forces one', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    final cast = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final aria = await ClassifierDao(db).createItem(moduleRef: cast, name: 'Aria');
    final ariaMod = await dao.createModule(nexusRef: nx, name: 'aria', kind: ModuleKind.drafter);
    expect(await WikiService.resolveName(db, 'ARIA', nx), 'module_$ariaMod');
    expect(await WikiService.resolveName(db, 'cobj:Aria', nx), 'cobj_$aria');
    expect(await WikiService.resolveName(db, 'Nobody', nx), isNull);
    // Another Nexus's names are not this one's.
    final other = await db.insert('nexus', {'name': 'Other'});
    expect(await WikiService.resolveName(db, 'Cast', other), isNull);
  });

  test('saving indexes links; a later entity claims a dangling one; a rename rewrites text', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    final book = await dao.createModule(nexusRef: nx, name: 'Book', kind: ModuleKind.author);
    final ch = await AuthorDao(db).createChapter(moduleRef: book, name: 'One');
    await AuthorDao(db).updateChapterContent(ch, 'Then [[Bram]] met [[Book|the book]].');
    var links = await db.rawQuery('SELECT target_key, target_text FROM wiki_link WHERE src_key=? ORDER BY id', ['bchp_$ch']);
    expect(links.map((l) => l['target_key']), [null, 'module_$book']);

    // Bram arrives later and claims the link typed before he existed.
    final cast = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final bram = await ClassifierDao(db).createItem(moduleRef: cast, name: 'Bram');
    links = await db.rawQuery('SELECT target_key FROM wiki_link WHERE src_key=? ORDER BY id', ['bchp_$ch']);
    expect(links.first['target_key'], 'cobj_$bram');

    // Renaming the module rewrites the chapter's text, alias kept.
    await dao.renameModule(book, 'Tome');
    final text = await db.rawQuery('SELECT chapter_content FROM book_chapter WHERE id=?', [ch]);
    expect(text.single['chapter_content'], 'Then [[Bram]] met [[Tome|the book]].');
    expect(await WikiService.backlinks(db, 'module_$book'), ['bchp_$ch']);
  });

  test('a module description and a Classifier field value are sources; rebuild restores the index', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    final cast = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    await dao.updateModuleDescription(cast, 'Everyone in [[Cast]].');
    final c = ClassifierDao(db);
    final aria = await c.createItem(moduleRef: cast, name: 'Aria');
    final bio = await c.createField(moduleRef: cast, description: 'Bio');
    await c.setValue(objectRef: aria, templateRef: bio, value: 'Friend of [[Cast]].');
    Future<List<String>> sources() async =>
        [for (final r in await db.rawQuery('SELECT src_key FROM wiki_link ORDER BY src_key')) r['src_key'] as String];
    expect(await sources(), ['cobj_$aria', 'module_$cast']);
    await db.delete('wiki_link');
    await WikiService.rebuildIndex(db);
    expect(await sources(), ['cobj_$aria', 'module_$cast']);
  });

  test('a key opens its page: a module, an element inside its module, a converted note', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    final cast = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final aria = await ClassifierDao(db).createItem(moduleRef: cast, name: 'Aria');
    expect(await EntityLocation.of(db, 'module_$cast'), '/hub/$nx/module/$cast');
    expect(await EntityLocation.of(db, 'cobj_$aria'), '/hub/$nx/module/$cast/item/cobj_$aria');
    await db.insert('note', {'nexus_ref': nx, 'title': 'Old', 'content': ''});
    await LegacyNotes.migrateAll(db);
    final mid = (await db.rawQuery("SELECT id FROM module WHERE name='Old'")).single['id'];
    final note = (await db.rawQuery('SELECT id FROM note')).single['id'];
    expect(await EntityLocation.of(db, 'note_$note'), '/hub/$nx/module/$mid');
    expect(await EntityLocation.of(db, 'file_1'), isNull);
    expect(await EntityLocation.of(db, 'cobj_999'), isNull);
  });

  test('dialogues, tables, sketch pages and map pins open their own pages; a deleted one takes its page', () async {
    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    Future<(int, int)> made(String name, ModuleKind kind, String table, Map<String, Object?> row) async {
      final m = await dao.createModule(nexusRef: nx, name: name, kind: kind);
      return (m, await db.insert(table, {'module_ref': m, ...row}));
    }

    final pages = {
      'sdlg': await made('Story', ModuleKind.narrator, 'story_dialogue', {'name': 'Meeting'}),
      'divt': await made('Rumors', ModuleKind.diviner, 'diviner_table', {'name': 'Tavern'}),
      'skpg': await made('Sketch', ModuleKind.sketcher, 'sketch_page', {'name': 'Harbor'}),
      'mevt': await made('Travels', ModuleKind.wanderer, 'map_event', {'x': 1, 'y': 2}),
    };
    for (final MapEntry(key: prefix, value: (m, id)) in pages.entries) {
      expect(await EntityLocation.of(db, '${prefix}_$id'), '/hub/$nx/module/$m/item/${prefix}_$id', reason: prefix);
      await db.insert('page_block', {'module_ref': m, 'item_key': '${prefix}_$id', 'block_type': 'text', 'content': 'Notes'});
    }
    Future<int> blocks(String key) async =>
        (await db.rawQuery('SELECT COUNT(*) AS c FROM page_block WHERE item_key=?', [key])).single['c'] as int;
    final (_, pin) = pages['mevt']!;
    expect(await blocks('mevt_$pin'), greaterThan(0));
    await WandererDao(db).deletePin(pin);
    expect(await blocks('mevt_$pin'), 0, reason: "a deleted pin's page goes with it");
    final (_, dlg) = pages['sdlg']!;
    await NarratorDao(db).deleteDialogue(dlg);
    expect(await blocks('sdlg_$dlg'), 0);
  });

  test('the [[ autocomplete sees only an unclosed link before the cursor', () {
    expect(WikiTextField.openLinkBefore('Hello [[Ar', 10), 'Ar');
    expect(WikiTextField.openLinkBefore('Hello [[Aria]] and', 18), isNull);
    expect(WikiTextField.openLinkBefore('[[', 2), '');
    expect(WikiTextField.openLinkBefore('a [[b|c', 7), isNull);
  });

  // Procress 26 part 4: the desktop's module links, read the same way here.
  test('[[obj:Module/Object]]: parse, label, resolve, a folder settles a clash', () async {
    final p = WikiPath.parse('obj:Stats/"HP/MP"')!;
    expect([p.ns, p.modules, p.object], ['obj', ['Stats'], 'HP/MP']);
    expect(WikiPath.parse('obj:Aria'), isNull, reason: 'a legacy Director link stays legacy');
    expect(WikiService.parse('[[mod:Book 1/Cast/Aria]] [[obj:Cast/Aria|her]]').map((m) => m.label), ['Aria', 'her']);

    final db = await openVault();
    final nx = await db.insert('nexus', {'name': 'W'});
    final dao = ModuleDao(db);
    final b1 = await dao.createModule(nexusRef: nx, name: 'Book 1', kind: ModuleKind.collector);
    final b2 = await dao.createModule(nexusRef: nx, name: 'Book 2', kind: ModuleKind.collector);
    final c1 = await dao.createModule(nexusRef: nx, parentId: b1, name: 'Cast', kind: ModuleKind.classifier);
    final c2 = await dao.createModule(nexusRef: nx, parentId: b2, name: 'Cast', kind: ModuleKind.classifier);
    final a1 = await ClassifierDao(db).createItem(moduleRef: c1, name: 'Aria');
    await ClassifierDao(db).createItem(moduleRef: c2, name: 'Aria');
    final bram = await ClassifierDao(db).createItem(moduleRef: c2, name: 'Bram');
    expect(await WikiService.resolveName(db, 'obj:Cast/Bram', nx), 'cobj_$bram');
    expect(await WikiService.resolveName(db, 'mod:Cast/Bram', nx), 'cobj_$bram');
    expect(await WikiService.resolveName(db, 'obj:Cast/Aria', nx), isNull, reason: 'two Arias: ambiguous');
    expect(await WikiService.resolveName(db, 'obj:book 1/Cast/aria', nx), 'cobj_$a1');
    expect(await WikiService.resolveName(db, 'obj:Book 3/Cast/Aria', nx), isNull);
  });
}

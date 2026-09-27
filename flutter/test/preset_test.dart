import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/page_template_service.dart';
import 'package:dracondex/data/services/preset_service.dart';

/// "Save page as template…" and "Mine" on the phone (Procress 14 part 4,
/// APP docs/TEMPLATES.md §3.3) — the row EXE db/preset.js writes, so a
/// template saved on either app applies on the other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  Future<(Database, int)> vault() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    return (db, await db.insert('nexus', {'name': 'Presets'}));
  }

  test('save captures look, view, keyed fields and both pages; the same name replaces', () async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    final (db, nx) = await vault();
    addTearDown(db.close);
    final m = await ModuleDao(db).createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    await PageTemplateService.apply(db, m, (await PageTemplateService.byId('classifier.characterWiki'))!);
    await db.insert('module_ui', {'module_ref': m, 'ui_key': 'activeView', 'ui_value': 'gallery'});
    await db.insert('module_ui', {'module_ref': m, 'ui_key': 'filterDef', 'ui_value': '{"x":1}'});

    await PresetService.save(db, nx, m, 'My wiki');
    await PresetService.save(db, nx, m, 'My wiki');
    final rows = await db.rawQuery('SELECT kind, name, spec FROM module_preset');
    expect(rows.length, 1, reason: 'saving under the same name is an update');
    final spec = jsonDecode(rows.first['spec'] as String) as Map;
    expect(rows.first['kind'], 'classifier');
    expect(spec['ui'], {'activeView': 'gallery'}, reason: 'filterDef names rows by id — never captured');
    expect((spec['fields'] as List).where((f) => f['key'] != null), isNotEmpty, reason: 'field keys ride along');
    expect(spec['page'], isNotEmpty);
    expect(spec['itemPage'], isNotEmpty);
  });

  test('Mine: same kind, with a page, never a bundle; applies with its fields and undoes', () async {
    await PageTemplateService.catalog(raw: File('assets/templates/pages.json').readAsStringSync());
    final (db, nx) = await vault();
    addTearDown(db.close);
    final dao = ModuleDao(db);
    final src = await dao.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    await PageTemplateService.apply(db, src, (await PageTemplateService.byId('classifier.characterWiki'))!);
    await PresetService.save(db, nx, src, 'Wiki');
    await db.insert('module_preset', {'nexus_ref': nx, 'kind': 'bundle', 'name': 'Wiki', 'spec': '{"modules":[]}'});
    await db.insert('module_preset', {'nexus_ref': nx, 'kind': 'classifier', 'name': 'Look only', 'spec': '{"icon":"svg:star"}'});

    final mine = await PresetService.mine(db, nx, 'classifier');
    expect(mine.map((t) => t.name), ['Wiki'], reason: 'no page → not a page template; bundles are never listed');
    expect(await PresetService.mine(db, nx, 'author'), isEmpty);

    final dst = await dao.createModule(nexusRef: nx, name: 'Beasts', kind: ModuleKind.classifier);
    await db.insert('page_block', {'module_ref': dst, 'block_type': 'text', 'content': 'mine', 'block_order': 0});
    final r = await PageTemplateService.apply(db, dst, mine.single);
    expect(r.fields, greaterThan(0));
    final comps = [for (final b in await db.rawQuery('SELECT component FROM page_block WHERE module_ref=? AND item_key IS NULL', [dst])) b['component']];
    final want = [for (final b in await db.rawQuery('SELECT component FROM page_block WHERE module_ref=? AND item_key IS NULL', [src])) b['component']];
    expect(comps, want);
    await PageTemplateService.restore(db, dst, r.old);
    expect([for (final b in await db.rawQuery('SELECT content FROM page_block WHERE module_ref=? AND item_key IS NULL', [dst])) b['content']], ['mine']);

    expect(await PresetService.delete(db, int.parse(mine.single.id.substring(2))), 1);
    expect(await PresetService.mine(db, nx, 'classifier'), isEmpty);
  });

  test('cleanSpec narrows a hand-edited row', () {
    final s = PresetService.cleanSpec(jsonEncode({
      'catType': 'weird',
      'fields': [
        {'name': 'Age', 'type': 'number', 'key': 'age'},
        {'name': 'Bad', 'type': 'nope', 'key': 'Bad Key'},
        {'type': 'text'},
      ],
      'page': [
        {'component': 'core.infobox', 'children': [[{'type': 'text', 'children': [[{'type': 'text', 'children': [[{'type': 'x'}]]}]]}]]},
      ],
      'extra': 1,
    }));
    expect(s.containsKey('catType'), isFalse);
    expect(s.containsKey('extra'), isFalse);
    expect(s['fields'], [
      {'name': 'Age', 'type': 'number', 'key': 'age', 'levelable': false, 'hasCondition': false},
      {'name': 'Bad', 'type': 'text', 'levelable': false, 'hasCondition': false},
    ]);
    final deep = ((((s['page'] as List).first as Map)['children'] as List).first as List).first as Map;
    expect(((deep['children'] as List).first as List).first, {'type': 'text'}, reason: 'two levels of children, no more');
    expect(PresetService.cleanSpec('not json'), isEmpty);
  });
}

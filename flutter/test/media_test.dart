import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/links/safe_launch.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/dao/page_block_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/assets/asset_store.dart';
import 'package:dracondex/features/page/component_registry.dart';
import 'package:dracondex/features/page/media_components.dart';
import 'package:dracondex/features/page/module_page.dart';
import 'package:dracondex/providers/db_providers.dart';

/// The media classes and blocks on the phone (Procress 14, APP
/// docs/MEDIA-EMBED.md): the same file classes as the desktop, the desktop's
/// blocks read from the same config, and only http(s) ever handed to a
/// browser.
void main() {
  sqfliteFfiInit();

  test('assetClass and the MIME types are the desktop\'s', () {
    final exe = jsonDecode(File('test/fixtures/exe_asset_media.json').readAsStringSync()) as Map<String, dynamic>;
    expect(assetClass, (exe['ASSET_CLASS'] as Map).cast<String, String>());
    final mime = {for (final e in (exe['MIME'] as Map).entries) e.key as String: '${e.value}'.split(';').first};
    expect(assetMime, mime);
  });

  test('a picker for a class offers its extensions', () {
    expect(extensionsOf({'pdf'}), ['pdf']);
    expect(extensionsOf({'model'}), ['glb', 'gltf', 'stl', 'obj']);
    expect(extensionsOf({'video'}), containsAll(['mp4', 'webm', 'mov', 'mkv']));
    const pdf = Asset(1, 'a.pdf', '/x/a.pdf', 'pdf', 1, false, null, null);
    const txt = Asset(2, 'a.txt', '/x/a.txt', 'txt', 1, false, null, null);
    expect(pdf.isOf({'pdf'}), isTrue);
    expect(txt.isOf({'pdf'}), isFalse, reason: 'a PDF block takes PDFs, not every doc');
    expect(pdf.mime, 'application/pdf');
  });

  test('only http(s) with a host reaches the browser', () {
    for (final ok in ['https://example.com', 'http://x.org/a?b=1', ' https://example.com/ ']) {
      expect(isSafeWebUrl(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'file:///etc/passwd',
      'javascript:alert(1)',
      'data:text/html,<b>x</b>',
      'intent://scan#Intent;scheme=zxing;end',
      'content://media/1',
      'ddx-file://1',
      'https:',
      'example.com',
      '',
      null,
    ]) {
      expect(isSafeWebUrl(bad), isFalse, reason: '$bad');
    }
  });

  test('a block\'s files: file_<id> references, nothing else', () {
    expect(mediaFileIds({'file': 'file_7'}, false), [7]);
    expect(mediaFileIds({'file': 'cobj_7'}, false), isEmpty);
    expect(mediaFileIds({'files': ['file_1', 'x', 'file_3', 4]}, true), [1, 3]);
    expect(mediaFileIds(const {}, true), isEmpty);
  });

  testWidgets('the blocks: a poster that opens the file, an empty one that asks for a file', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // a 1×1 PNG: the "first frame" the desktop keeps as a video's proxy
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    final (db, mod) = (await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final sql in vaultCreateStatements) {
        await db.execute(sql);
      }
      final nx = await db.insert('nexus', {'name': 'World'});
      final m = await ModuleDao(db).createModule(nexusRef: nx, name: 'Films', kind: ModuleKind.drafter);
      Future<int> file(String name, String type, [Uint8List? proxy]) => db.insert('import_file', {
            'nexus_ref': nx, 'file_name': name, 'file_path': '/nowhere/$name', 'file_type': type, 'proxy': proxy, //
          });
      final v = await file('trailer.mp4', 'mp4', png);
      final a = await file('theme.mp3', 'mp3');
      final p = await file('map.pdf', 'pdf');
      final g = await file('ship.glb', 'glb');
      final dao = PageBlockDao(db);
      await dao.add(m, null, NewBlock(component: 'core.video', config: {'opts': {'file': 'file_$v', 'caption': 'The first cut'}}));
      await dao.add(m, null, NewBlock(component: 'core.audio', config: {'opts': {'files': ['file_$a'], 'title': 'Score'}}));
      await dao.add(m, null, NewBlock(component: 'core.pdf', config: {'opts': {'file': 'file_$p'}}));
      await dao.add(m, null, NewBlock(component: 'core.model3d', config: {'opts': {'file': 'file_$g'}}));
      await dao.add(m, null, NewBlock(component: 'core.media', config: {'opts': {'files': ['file_$v', 'file_$g', 'file_$a']}}));
      // a video block pointed at a PDF shows as empty rather than a wrong file
      await dao.add(m, null, NewBlock(component: 'core.video', config: {'opts': {'file': 'file_$p'}}));
      return (db, m);
    }))!;
    addTearDown(() => tester.runAsync(db.close));
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: ModulePage(moduleId: mod))),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(find.text('trailer.mp4'), findsOneWidget);
    expect(find.text('The first cut'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('theme.mp3'), findsOneWidget);
    expect(find.text('map.pdf'), findsOneWidget);
    expect(find.text('ship.glb'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2), reason: "the video's kept frame, in its block and in the mixed grid");
    expect(find.text('Choose a file'), findsOneWidget);
    expect(find.text('No file yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('every media block is registered', () {
    for (final id in mediaBlockKinds.keys) {
      expect(components[id], isNotNull, reason: id);
    }
  });
}

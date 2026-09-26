import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dracondex/core/database/vault_schema.g.dart';
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/data/dao/author_dao.dart';
import 'package:dracondex/data/dao/chronicler_dao.dart';
import 'package:dracondex/data/dao/classifier_dao.dart';
import 'package:dracondex/data/dao/module_dao.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/data/services/export/doc_model.dart';
import 'package:dracondex/data/services/export/doc_source.dart';
import 'package:dracondex/data/services/export/export_service.dart';
import 'package:dracondex/data/services/export/pdf_export.dart';
import 'package:dracondex/data/services/export/table_export.dart';
import 'package:dracondex/features/export/export_sheet.dart';

/// The phone's exports (Procress 14, APP docs/EXPORT-DECOR.md E1–E8): what
/// each file must be for the program that opens it. Set DDX_EXPORT_OUT to a
/// folder to keep the files for epubcheck / python-docx / openpyxl.
void main() {
  sqfliteFfiInit();
  final out = Platform.environment['DDX_EXPORT_OUT'];

  late Database db;
  late int nx, cast, book, events, notes;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    nx = await db.insert('nexus', {'name': 'World'});
    final mods = ModuleDao(db);
    cast = await mods.createModule(nexusRef: nx, name: 'Cast', kind: ModuleKind.classifier);
    final cls = ClassifierDao(db);
    final hp = await cls.createField(moduleRef: cast, description: 'HP', attributeType: 'number');
    final motto = await cls.createField(moduleRef: cast, description: 'Motto', attributeType: 'text');
    await cls.createField(moduleRef: cast, description: 'Double', attributeType: 'formula');
    await db.rawUpdate('UPDATE classifier_template SET options=? WHERE description=?', ['{"expr":"{HP} * 2"}', 'Double']);
    final ally = await cls.createField(moduleRef: cast, description: 'Ally', attributeType: 'relation');
    final ana = await cls.createItem(moduleRef: cast, name: 'อานา');
    final bram = await cls.createItem(moduleRef: cast, name: 'Bram, "the Bold"');
    await cls.setValue(objectRef: ana, templateRef: hp, value: '-5');
    await cls.setValue(objectRef: ana, templateRef: motto, value: '=HYPERLINK("http://x")');
    await cls.setValue(objectRef: bram, templateRef: motto, value: '@once');
    await cls.addFieldRelation(ana, ally, 'cobj_$bram');
    await cls.updateItem(ana, name: 'อานา', note: 'ผู้พิทักษ์ **ประตู** แห่ง [[Bram, "the Bold"|Bram]]');

    book = await mods.createModule(nexusRef: nx, name: 'The Book', kind: ModuleKind.author);
    final a = AuthorDao(db);
    final c1 = await a.createChapter(moduleRef: book, name: 'Arrival', label: '1');
    await a.updateChapterContent(
      c1,
      '# บทนำ\n\nIt began with *rain* & [a link](https://example.com).\n\n- one\n- two\n  - deeper\n\n> quoted',
    );
    final c2 = await a.createChapter(moduleRef: book, name: 'Departure', label: '2');
    await a.updateChapterContent(c2, '<div>She <b>left</b>.<br>Alone.</div><ol><li>first</li><li>second</li></ol>');

    events = await mods.createModule(nexusRef: nx, name: 'Ages', kind: ModuleKind.chronicler);
    final ch = ChroniclerDao(db);
    final tl = await ch.ensureTimeline(events);
    await ch.createEvent(timelineId: tl, startDateId: await ch.ensureDate(day: 3, month: 2, years: 1020), name: 'Siege');

    notes = await mods.createModule(nexusRef: nx, name: 'Notes', kind: ModuleKind.drafter);
    await db.rawUpdate('UPDATE module SET description=? WHERE id=?', ['Plain *notes*.', notes]);
  });
  tearDown(() => db.close());

  Future<ExportOutcome> run(
    int moduleId,
    ExportFormat f, {
    ExportPrefs prefs = const ExportPrefs(),
    String? itemKey,
    PdfFonts? fonts,
  }) async {
    final m = await db.rawQuery('SELECT name FROM module WHERE id=?', [moduleId]);
    final r = await ExportService.run(
      db,
      nexusId: nx,
      moduleId: moduleId,
      moduleName: '${m.first['name']}',
      format: f,
      prefs: prefs,
      itemKey: itemKey,
      fonts: fonts,
    );
    if (out != null && r.ok) File('$out/${r.name}').writeAsBytesSync(r.bytes!);
    return r;
  }

  Map<String, String> unzipText(Uint8List b) => {
    for (final f in ZipDecoder().decodeBytes(b))
      if (f.isFile && !f.name.startsWith('word/media') && !f.name.contains('/images/')) f.name: utf8.decode(f.content as List<int>),
  };

  test('CSV: BOM, the name first, quoting, formula injection guarded, numbers left alone', () async {
    final r = await run(cast, ExportFormat.csv);
    expect(r.bytes!.sublist(0, 3), [0xef, 0xbb, 0xbf]);
    final lines = utf8.decode(r.bytes!.sublist(3)).split('\r\n');
    expect(lines.first, 'name,HP,Motto,Ally');
    expect(lines[1], 'อานา,-5,"\'=HYPERLINK(""http://x"")","Bram, ""the Bold"""');
    expect(lines[2], '"Bram, ""the Bold""",,\'@once,');
    expect(r.skipped, ['Double']);
    expect(r.count, 2);
  });

  test('csvCell and isoDate', () {
    expect(csvCell('+1', 'text'), "'+1");
    expect(csvCell('-1', 'number'), '-1');
    expect(csvCell(' pad', 'text'), '" pad"');
    expect(isoDate('3-2-12'), '3-2-12');
    expect(isoDate('3/2/2024'), '2024-02-03');
  });

  test('XLSX: a sheet per table, the header frozen, a number cell as a number', () async {
    final r = await run(cast, ExportFormat.xlsx);
    final files = unzipText(r.bytes!);
    expect(files.keys, containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml']));
    final sheet = files['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('state="frozen"'));
    expect(sheet, contains('<c r="B2"><v>-5</v></c>'));
    expect(files['xl/workbook.xml'], contains('name="Cast"'));
    expect(sheetNames(const [ExportTable('a/b', [], []), ExportTable('A B', [], [])]), ['a b', 'A B 2']);
  });

  test('a Chronicler exports its events as a table and a document', () async {
    final csv = utf8.decode((await run(events, ExportFormat.csv)).bytes!);
    expect(csv, contains('Siege,1020.02.03,'));
    final doc = await moduleDocument(db, events);
    expect(doc!.sections.single.title, 'Siege');
  });

  test('DOCX: every part is XML, a heading per section, the property table, links as hyperlinks', () async {
    final r = await run(book, ExportFormat.docx);
    final files = unzipText(r.bytes!);
    expect(
      files.keys,
      containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml', 'word/_rels/document.xml.rels']),
    );
    final doc = files['word/document.xml']!;
    expect(RegExp('w:val="Heading1"').allMatches(doc).length, 2);
    expect(doc, contains('<w:pageBreakBefore/>'));
    expect(doc, contains('<w:hyperlink r:id="rId100">'));
    expect(files['word/_rels/document.xml.rels'], contains('Target="https://example.com" TargetMode="External"'));
    expect(doc, contains('It began with '));
    expect(doc, isNot(contains('<b>')));

    final cls = unzipText((await run(cast, ExportFormat.docx)).bytes!)['word/document.xml']!;
    expect(cls, contains('PropTable'));
    expect(cls, contains('>Bram, &quot;the Bold&quot;<'));
    expect(cls, contains('Bram</w:t>')); // the wikilink's alias, not the brackets
    expect(cls, isNot(contains('[[')));
  });

  test('EPUB: mimetype first and stored, a nav, a chapter per section', () async {
    final r = await run(book, ExportFormat.epub);
    final b = r.bytes!;
    final head = ByteData.sublistView(b);
    expect(head.getUint32(0, Endian.little), 0x04034b50);
    expect(head.getUint16(8, Endian.little), 0, reason: 'mimetype must be stored');
    expect(ascii.decode(b.sublist(30, 38)), 'mimetype');
    final files = unzipText(b);
    expect(files['mimetype'], 'application/epub+zip');
    expect(files['OEBPS/content.opf'], contains('<dc:identifier id="bookid">urn:uuid:'));
    expect(files.keys, containsAll(['OEBPS/nav.xhtml', 'OEBPS/ch-001.xhtml', 'OEBPS/ch-002.xhtml']));
    expect(files['OEBPS/ch-002.xhtml'], contains('<ol>\n<li>first</li>'));
    expect((await run(cast, ExportFormat.epub)).code, 'empty');
  });

  test('Markdown: a folder per module, frontmatter, the wikilink kept', () async {
    final r = await run(cast, ExportFormat.md);
    final files = unzipText(r.bytes!);
    final ana = files['Cast/อานา.md']!;
    expect(ana, startsWith('---\ncategory: "[[Cast]]"\nHP: -5\n'));
    expect(ana, contains('Ally:\n  - "[[Bram, \\"the Bold\\"]]"'));
    expect(ana, contains('Double: "= '));
    expect(ana, endsWith('[[Bram, "the Bold"|Bram]]'));
    final all = unzipText((await run(cast, ExportFormat.md, prefs: const ExportPrefs(mdScope: 'nexus'))).bytes!);
    expect(all.keys, containsAll(['World/Cast/อานา.md', 'World/The Book/1 Arrival.md', 'World/Notes/Notes.md']));
  });

  test('HTML: one page, a contents list, the property table', () async {
    final r = await run(cast, ExportFormat.html);
    final page = unzipText(r.bytes!)['index.html']!;
    expect(page, contains('<nav class="toc">'));
    expect(page, contains('<table class="props"><tr><th>HP</th><td>-5</td></tr>'));
    final one = unzipText((await run(cast, ExportFormat.html, itemKey: 'cobj_1')).bytes!)['index.html']!;
    expect(one, isNot(contains('Bram, &quot;the Bold&quot;</h2>')));
  });

  test('the Markdown and HTML reader', () {
    final md = fromMarkdown('## Head\ntext **bold** and *it* `code`\n\n1. a\n2. b\n\n---\n```\nx < y\n```');
    expect(md.map((b) => b.t), [BlockKind.h, BlockKind.p, BlockKind.li, BlockKind.li, BlockKind.hr, BlockKind.code]);
    expect(md[1].runs.where((r) => r.b).map((r) => r.text).join(), 'bold');
    expect(md[1].runs.where((r) => r.i).map((r) => r.text).join(), 'it');
    expect(md[3].n, 2);
    expect(toXhtml(md), contains('<pre><code>x &lt; y</code></pre>'));
    final html = fromHtml('<p>a&amp;b <a href="https://x.org">x</a></p><ul><li>one</li></ul><pre>  keep\n  me</pre>');
    expect(html.map((b) => b.t), [BlockKind.p, BlockKind.li, BlockKind.code]);
    expect(html[0].runs.last.href, 'https://x.org');
    expect(html[2].text, '  keep\n  me');
  });

  test('PDF: builds with the Thai fallback, a page per chapter', () async {
    pw.Font font(String f) => pw.Font.ttf(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync()));
    final fonts = PdfFonts(font('NotoSans-Regular.ttf'), font('NotoSans-Bold.ttf'), [
      font('NotoSansThai-Regular.ttf'),
      font('NotoSansThai-Bold.ttf'),
    ]);
    final r = await run(
      book,
      ExportFormat.pdf,
      prefs: const ExportPrefs(scope: 'module'),
      fonts: fonts,
    );
    expect(ascii.decode(r.bytes!.sublist(0, 5)), '%PDF-');
    expect(r.count, 2);
    final cls = await run(
      cast,
      ExportFormat.pdf,
      prefs: const ExportPrefs(scope: 'module', paper: 'A5', orientation: 'landscape'),
      fonts: fonts,
    );
    expect(cls.ok, isTrue);
  });

  test('prefs round-trip through module_ui with EXE\'s keys', () async {
    await const ExportPrefs(fmt: 'docx', paper: 'Letter', toc: false).save(db, book);
    final p = await ExportPrefs.load(db, book);
    expect((p.fmt, p.paper, p.toc), ('docx', 'Letter', false));
    expect(ExportPrefs.decode('{"fmt":"view","paper":"B9"}').paper, 'A4');
  });

  test('cards the kind cannot use say why', () {
    expect(exportBlocked(ExportFormat.epub, 'classifier'), 'exportOnlyBooks');
    expect(exportBlocked(ExportFormat.csv, 'author'), 'exportOnlyTables');
    expect(exportBlocked(ExportFormat.pdf, 'collector'), 'exportNoPage');
    expect(exportBlocked(ExportFormat.docx, 'drafter'), isNull);
  });

  testWidgets('the sheet: every card, the ones this kind cannot use dimmed with why, PDF options', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    const module = ModuleModel(id: 1, nexusRef: 1, name: 'Cast', kind: ModuleKind.classifier, createdAt: '', updatedAt: '');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.forName('midnight'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: ExportSheet(
              module: module,
              initial: ExportPrefs(fmt: 'epub'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final t in ['PDF', 'Word (DOCX)', 'EPUB (e-book)', 'Excel (XLSX)', 'CSV', 'Markdown']) {
      expect(find.textContaining(t), findsWidgets, reason: t);
    }
    // a book-only format on a Classifier: dimmed, with the reason, and not
    // the one picked even though it was the saved choice
    expect(find.text('Author books only'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget, reason: 'fell back to PDF, whose options show');
    await tester.tap(find.text('EPUB (e-book)'));
    await tester.pump();
    expect(find.text('Paper'), findsOneWidget);
    await tester.tap(find.text('CSV'));
    await tester.pump();
    expect(find.text('Paper'), findsNothing);
    expect(find.textContaining('Import CSV reads it back'), findsOneWidget);
  });
}

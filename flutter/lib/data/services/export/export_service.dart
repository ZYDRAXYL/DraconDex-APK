import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

import '../mddx.dart';
import 'doc_source.dart';
import 'docx_export.dart';
import 'epub_export.dart';
import 'html_export.dart';
import 'md_export.dart';
import 'pdf_export.dart';
import 'table_export.dart';
import 'zip_writer.dart';

/// Every way out of the app for one page (Procress 14, APP
/// docs/EXPORT-DECOR.md E8 on the phone). The Export sheet names a format;
/// this reads the vault and hands back the file's bytes, which the sheet
/// shares (or prints) — the same XFile.fromData path on Android and web.
enum ExportFormat { pdf, docx, epub, xlsx, csv, html, md, mddx }

/// The last choices, per module, in module_ui 'exportPrefs' — the keys EXE
/// writes, so a vault opened on either side remembers the same thing.
class ExportPrefs {
  final String fmt, scope, mdScope, paper, orientation;
  final bool headerFooter, toc;
  const ExportPrefs({
    this.fmt = 'pdf',
    this.scope = 'page',
    this.mdScope = 'module',
    this.paper = 'A4',
    this.orientation = 'portrait',
    this.headerFooter = true,
    this.toc = true,
  });

  factory ExportPrefs.decode(String? raw) {
    Map<String, Object?> m = const {};
    try {
      final v = jsonDecode(raw ?? '{}');
      if (v is Map) m = v.cast<String, Object?>();
    } catch (_) {}
    String pick(String k, List<String> ok, String d) => ok.contains(m[k]) ? m[k] as String : d;
    return ExportPrefs(
      fmt: pick('fmt', [for (final f in ExportFormat.values) f.name, 'view'], 'pdf'),
      scope: pick('scope', ['page', 'module'], 'page'),
      mdScope: pick('mdScope', ['module', 'nexus'], 'module'),
      paper: pick('paper', ['A4', 'Letter', 'A5'], 'A4'),
      orientation: pick('orientation', ['portrait', 'landscape'], 'portrait'),
      headerFooter: m['headerFooter'] is bool ? m['headerFooter'] as bool : true,
      toc: m['toc'] is bool ? m['toc'] as bool : true,
    );
  }

  ExportPrefs copyWith({String? fmt, String? scope, String? mdScope, String? paper, String? orientation, bool? headerFooter, bool? toc}) =>
      ExportPrefs(
        fmt: fmt ?? this.fmt,
        scope: scope ?? this.scope,
        mdScope: mdScope ?? this.mdScope,
        paper: paper ?? this.paper,
        orientation: orientation ?? this.orientation,
        headerFooter: headerFooter ?? this.headerFooter,
        toc: toc ?? this.toc,
      );

  String encode() => jsonEncode({
    'fmt': fmt,
    'scope': scope,
    'mdScope': mdScope,
    'paper': paper,
    'orientation': orientation,
    // EXE's own key; the phone always prints light.
    'theme': 'print',
    'headerFooter': headerFooter,
    'toc': toc,
  });

  static Future<ExportPrefs> load(DatabaseExecutor db, int moduleId) async {
    final r = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='exportPrefs'", [moduleId]);
    return ExportPrefs.decode(r.isEmpty ? null : r.first['ui_value'] as String?);
  }

  Future<void> save(DatabaseExecutor db, int moduleId) => db.insert('module_ui', {
    'module_ref': moduleId,
    'ui_key': 'exportPrefs',
    'ui_value': encode(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

const _docKinds = ['author', 'classifier', 'chronicler', 'drafter', 'inspector'];
const _tableKinds = ['classifier', 'chronicler'];

/// Why [f] cannot run for [kind] — an l10n key's name, or null when it can.
/// The sheet dims the card and says this rather than hiding it, so the
/// user learns where CSV lives instead of wondering where it went.
String? exportBlocked(ExportFormat f, String kind) {
  if (kind == 'collector' && (f == ExportFormat.pdf || f == ExportFormat.html)) return 'exportNoPage';
  switch (f) {
    case ExportFormat.docx:
      return _docKinds.contains(kind) ? null : 'exportOnlyDocs';
    case ExportFormat.epub:
      return kind == 'author' ? null : 'exportOnlyBooks';
    case ExportFormat.xlsx:
    case ExportFormat.csv:
      return _tableKinds.contains(kind) ? null : 'exportOnlyTables';
    default:
      return null;
  }
}

/// A finished export: the file, or why there is none ([code]: `empty`).
class ExportOutcome {
  final Uint8List? bytes;
  final String name, mime;
  final String? code;

  /// What the file holds — rows, sections, chapters or files.
  final int count;
  final int pictures, missing, moreTimelines;
  final List<String> skipped;
  const ExportOutcome(
    this.bytes,
    this.name,
    this.mime, {
    this.code,
    this.count = 0,
    this.pictures = 0,
    this.missing = 0,
    this.moreTimelines = 0,
    this.skipped = const [],
  });
  const ExportOutcome.fail(this.code)
    : bytes = null,
      name = '',
      mime = '',
      count = 0,
      pictures = 0,
      missing = 0,
      moreTimelines = 0,
      skipped = const [];
  bool get ok => bytes != null;
}

String _safeFile(String s) {
  final v = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  return v.isEmpty ? 'export' : (v.length > 80 ? v.substring(0, 80) : v);
}

/// The fonts the PDF draws with — NotoSans, with Noto Sans Thai behind it.
Future<PdfFonts> loadPdfFonts() async {
  Future<pw.Font> f(String p) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$p'));
  return PdfFonts(await f('NotoSans-Regular.ttf'), await f('NotoSans-Bold.ttf'), [
    await f('NotoSansThai-Regular.ttf'),
    await f('NotoSansThai-Bold.ttf'),
  ]);
}

class ExportService {
  /// [itemKey]: an element page's export — only that element.
  static Future<ExportOutcome> run(
    Database db, {
    required int nexusId,
    required int moduleId,
    required String moduleName,
    String? itemKey,
    required ExportFormat format,
    required ExportPrefs prefs,
    String lang = 'en',
    PdfFonts? fonts,
  }) async {
    final base = _safeFile(moduleName);
    switch (format) {
      case ExportFormat.csv:
      case ExportFormat.xlsx:
        final tables = await tablesFor(db, moduleId);
        if (tables.isEmpty) return const ExportOutcome.fail('empty');
        final skipped = tables.expand((t) => t.skipped).toList();
        if (format == ExportFormat.csv) {
          return ExportOutcome(
            Uint8List.fromList(utf8.encode(toCsv(tables.first))),
            '$base.csv',
            'text/csv',
            count: tables.first.rows.length,
            moreTimelines: tables.length - 1,
            skipped: skipped,
          );
        }
        return ExportOutcome(
          writeZip(xlsxEntries(tables)),
          '$base.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          count: tables.fold(0, (n, t) => n + t.rows.length),
          skipped: skipped,
        );

      case ExportFormat.md:
        final md = await markdownEntries(db, nexusId, moduleId: prefs.mdScope == 'nexus' ? null : moduleId);
        if (md == null) return const ExportOutcome.fail('empty');
        return ExportOutcome(
          writeZip(md.entries),
          '$base.zip',
          'application/zip',
          count: md.files,
          pictures: md.pictures,
          missing: md.missing,
        );

      case ExportFormat.mddx:
        final bytes = await Mddx.export(db, nexusId, moduleId);
        if (bytes == null) return const ExportOutcome.fail('empty');
        return ExportOutcome(bytes, '$base.mddx', 'application/json');

      case ExportFormat.docx:
      case ExportFormat.epub:
      case ExportFormat.html:
      case ExportFormat.pdf:
        var doc = await moduleDocument(db, moduleId, anyKind: format == ExportFormat.pdf || format == ExportFormat.html);
        if (doc == null) return const ExportOutcome.fail('empty');
        if (itemKey != null) {
          doc = doc.only(itemKey);
        } else if (format == ExportFormat.pdf && prefs.scope != 'module') {
          doc = doc.pageOnly;
        }
        final allow = switch (format) {
          ExportFormat.docx => docxPictureFormats,
          ExportFormat.epub => epubPictureFormats,
          ExportFormat.html => htmlPictureFormats,
          _ => pdfPictureFormats,
        };
        final ids = doc.allImages.toSet();
        final pictures = await loadMedia(db, ids, allow);
        final missing = ids.length - pictures.length;
        final sections = doc.sections.length;
        switch (format) {
          case ExportFormat.docx:
            return ExportOutcome(
              writeZip(docxEntries(doc, pictures)),
              '$base.docx',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              count: sections,
              pictures: pictures.length,
              missing: missing,
            );
          case ExportFormat.epub:
            final e = epubEntries(doc, pictures, lang: lang);
            if (e == null || e.isEmpty) return const ExportOutcome.fail('empty');
            return ExportOutcome(
              writeZip(e),
              '$base.epub',
              'application/epub+zip',
              count: sections,
              pictures: pictures.length,
              missing: missing,
            );
          case ExportFormat.html:
            return ExportOutcome(
              writeZip(htmlEntries(doc, pictures, lang: lang)),
              '$base.zip',
              'application/zip',
              count: sections,
              pictures: pictures.length,
              missing: missing,
            );
          default:
            final bytes = await buildPdf(
              doc,
              pictures,
              fonts ?? await loadPdfFonts(),
              PdfOptions(paper: prefs.paper, landscape: prefs.orientation == 'landscape', headerFooter: prefs.headerFooter, toc: prefs.toc),
            );
            return ExportOutcome(bytes, '$base.pdf', 'application/pdf', count: sections, pictures: pictures.length, missing: missing);
        }
    }
  }
}

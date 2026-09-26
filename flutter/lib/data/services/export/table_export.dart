import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/entity/entity_kinds.dart';
import 'zip_writer.dart';

/// Tables out: CSV / XLSX — the port of EXE db/table-export.js (Procress 14,
/// APP docs/EXPORT-DECOR.md E4). A Classifier is a table already — one row
/// per element, one column per field — and a Chronicler's events are one.
///
/// CSV is written so that CSV import reads it back into the same Classifier:
/// the name first, a UTF-8 BOM (Excel on Thai Windows otherwise reads it as
/// windows-874), true/false for a checkbox, ISO dates. XLSX is the smallest
/// SpreadsheetML Excel, Sheets and Numbers all open.
class ExportTable {
  final String name;
  final List<(String name, String type)> columns;
  final List<List<String>> rows;
  final List<String> skipped;
  const ExportTable(this.name, this.columns, this.rows, [this.skipped = const []]);
}

/// A stored date is d-m-y (or d/m/y) with an optional h:mi. A four-digit
/// year becomes ISO so import reads it as a date again; a story's own year
/// 12 stays as it was — a date nothing outside the app can hold.
String isoDate(String? v) {
  final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{1,6})(?:\s+(\d{1,2}):(\d{2}))?$').firstMatch((v ?? '').trim());
  if (m == null || m[3]!.length != 4) return v ?? '';
  return '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
}

String cellOf(String type, String? raw) {
  final v = raw ?? '';
  switch (type) {
    case 'checkbox':
      return v == '1' || v == 'true' ? 'true' : (v.isEmpty ? '' : 'false');
    case 'date':
      return isoDate(v);
    case 'multi':
      try {
        final a = jsonDecode(v);
        return a is List ? a.join(', ') : v;
      } catch (_) {
        return v;
      }
  }
  return v;
}

/// A formula is computed by the app from the other fields, and import
/// cannot take one back — it is left out and named, not written empty.
Future<ExportTable?> classifierTable(DatabaseExecutor db, int moduleId) async {
  final mod = await db.rawQuery('SELECT name FROM module WHERE id=?', [moduleId]);
  if (mod.isEmpty) return null;
  final templates = await db.rawQuery(
    'SELECT id, description, attribute_type FROM classifier_template WHERE module_ref=? AND object_ref IS NULL ORDER BY display_order, id',
    [moduleId],
  );
  final fields = templates.where((t) => t['attribute_type'] != 'formula').toList();
  final vals = <int, Map<int, String?>>{};
  for (final r in await db.rawQuery(
    'SELECT a.object_ref, a.template_ref, a.attribute_value FROM classifier_attribute a JOIN classifier_object o ON a.object_ref=o.id WHERE o.module_ref=?',
    [moduleId],
  )) {
    (vals[r['object_ref'] as int] ??= {})[r['template_ref'] as int] = r['attribute_value'] as String?;
  }
  final rows = <List<String>>[];
  for (final o in await db.rawQuery('SELECT id, name FROM classifier_object WHERE module_ref=? ORDER BY display_order, id', [moduleId])) {
    final oid = o['id'] as int;
    final row = ['${o['name']}'];
    for (final tp in fields) {
      final type = tp['attribute_type'] as String? ?? 'text';
      if (type == 'relation') {
        final names = <String>[];
        for (final r in await db.rawQuery('SELECT to_key FROM entity_relation WHERE from_key=? AND rel_type=? ORDER BY id', [
          'cobj_$oid',
          'ctpl_${tp['id']}',
        ])) {
          names.add(await EntityKinds.nameOf(db, r['to_key'] as String) ?? '${r['to_key']}');
        }
        row.add(names.join('; '));
      } else {
        row.add(cellOf(type, vals[oid]?[tp['id'] as int]));
      }
    }
    rows.add(row);
  }
  return ExportTable(
    '${mod.first['name']}',
    [('name', 'text'), for (final tp in fields) ('${tp['description']}', tp['attribute_type'] as String? ?? 'text')],
    rows,
    [
      for (final tp in templates)
        if (tp['attribute_type'] == 'formula') '${tp['description']}',
    ],
  );
}

String _stamp(Map<String, Object?> e, String p) {
  if (e['${p}_years'] == null) return '';
  String two(Object? n) => '${n ?? 0}'.padLeft(2, '0');
  final h = e['${p}_hour'] as int? ?? 0, mi = e['${p}_minute'] as int? ?? 0;
  final time = h != 0 || mi != 0 ? ' ${two(h)}:${two(mi)}' : '';
  return '${e['${p}_years']}.${two(e['${p}_month'])}.${two(e['${p}_day'])}$time';
}

/// One table per timeline — each its own XLSX sheet. A CSV holds one table,
/// so a CSV of a Chronicler is its first timeline and says how many more.
Future<List<ExportTable>> chroniclerTables(DatabaseExecutor db, int moduleId) async {
  final out = <ExportTable>[];
  for (final tl in await db.rawQuery('SELECT id, line_name FROM timeline WHERE module_ref=? ORDER BY id', [moduleId])) {
    final events = await db.rawQuery(
      '''
      SELECT te.event_name, te.story, c.color_code,
        s.day s_day, s.month s_month, s.years s_years, s.hour s_hour, s.minute s_minute,
        e.day e_day, e.month e_month, e.years e_years, e.hour e_hour, e.minute e_minute
      FROM timeline_event te
      LEFT JOIN timeline_date s ON te.start_at=s.id LEFT JOIN timeline_date e ON te.end_at=e.id
      LEFT JOIN use_color c ON te.color=c.id
      WHERE te.timeline_id=? ORDER BY s.years, s.month, s.day, s.hour, s.minute, te.id''',
      [tl['id']],
    );
    out.add(
      ExportTable(
        tl['line_name'] as String? ?? '',
        [
          for (final n in ['event', 'start', 'end', 'story', 'color']) (n, 'text'),
        ],
        [
          for (final e in events)
            ['${e['event_name'] ?? ''}', _stamp(e, 's'), _stamp(e, 'e'), '${e['story'] ?? ''}', '${e['color_code'] ?? ''}'],
        ],
      ),
    );
  }
  return out;
}

Future<List<ExportTable>> tablesFor(DatabaseExecutor db, int moduleId) async {
  final k = await db.rawQuery('SELECT kind FROM module WHERE id=?', [moduleId]);
  final kind = k.isEmpty ? null : k.first['kind'];
  if (kind == 'classifier') {
    final t = await classifierTable(db, moduleId);
    return t == null ? [] : [t];
  }
  if (kind == 'chronicler') return chroniclerTables(db, moduleId);
  return [];
}

// ── CSV ─────────────────────────────────────────────────────────────────
// RFC 4180 + CRLF + BOM. A text cell a spreadsheet would run as a formula
// (= + - @, or a leading tab/CR) gets a ' in front — OWASP's CSV-injection
// advice. A number column is exempt, or -5 would stop being a number.
final _risky = RegExp(r'^[=+\-@\t\r]');

String csvCell(String v, String? type) {
  var s = v;
  if (type != 'number' && _risky.hasMatch(s)) s = "'$s";
  return RegExp(r'[",\r\n;]').hasMatch(s) || RegExp(r'^\s|\s$').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String toCsv(ExportTable t) {
  final lines = [t.columns.map((c) => csvCell(c.$1, 'text')).join(',')];
  for (final r in t.rows) {
    lines.add([for (var i = 0; i < r.length; i++) csvCell(r[i], i < t.columns.length ? t.columns[i].$2 : null)].join(','));
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

// ── XLSX ────────────────────────────────────────────────────────────────
String _xml(String s) => s
    .replaceAll(RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]'), '')
    .replaceAllMapped(RegExp(r'[&<>"]'), (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[m[0]]!);

String colName(int i) {
  var s = '';
  for (var n = i + 1; n > 0; n = (n - 1) ~/ 26) {
    s = String.fromCharCode(65 + (n - 1) % 26) + s;
  }
  return s;
}

/// Excel refuses a sheet name over 31 characters, with []:*?/\ in it, or a
/// repeat of another sheet's (case-insensitively).
List<String> sheetNames(List<ExportTable> tables) {
  final used = <String>{};
  return [
    for (var i = 0; i < tables.length; i++)
      () {
        var base = tables[i].name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
        if (base.isEmpty) base = 'Sheet${i + 1}';
        if (base.length > 31) base = base.substring(0, 31);
        var name = base;
        for (var k = 2; used.contains(name.toLowerCase()); k++) {
          final cut = 31 - '$k'.length - 1;
          name = '${base.length > cut ? base.substring(0, cut) : base} $k';
        }
        used.add(name.toLowerCase());
        return name;
      }(),
  ];
}

final _num = RegExp(r'^-?\d+(\.\d+)?$');

String _sheetXml(ExportTable t) {
  String row(List<String> cells, int r, bool head) =>
      '<row r="$r">${[for (var i = 0; i < cells.length; i++) (!head && i < t.columns.length && t.columns[i].$2 == 'number' && _num.hasMatch(cells[i])) ? '<c r="${colName(i)}$r"><v>${cells[i]}</v></c>' : '<c r="${colName(i)}$r" t="inlineStr"${head ? ' s="1"' : ''}><is><t xml:space="preserve">${_xml(cells[i])}</t></is></c>'].join()}</row>';
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetData>${row([for (final c in t.columns) c.$1], 1, true)}${[for (var i = 0; i < t.rows.length; i++) row(t.rows[i], i + 2, false)].join()}</sheetData>
</worksheet>''';
}

List<ZipEntry> xlsxEntries(List<ExportTable> tables) {
  final names = sheetNames(tables);
  final n = [for (var i = 1; i <= tables.length; i++) i];
  return [
    ZipEntry('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
${n.map((i) => '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join('\n')}
</Types>'''),
    ZipEntry('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>'''),
    ZipEntry('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>${n.map((i) => '<sheet name="${_xml(names[i - 1])}" sheetId="$i" r:id="rId$i"/>').join()}</sheets>
</workbook>'''),
    ZipEntry('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${n.map((i) => '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>').join('\n')}
<Relationship Id="rId${n.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''),
    ZipEntry('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>'''),
    for (var i = 0; i < tables.length; i++) ZipEntry('xl/worksheets/sheet${i + 1}.xml', _sheetXml(tables[i])),
  ];
}

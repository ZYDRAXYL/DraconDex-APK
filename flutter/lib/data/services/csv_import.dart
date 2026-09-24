import 'dart:convert';
import 'dart:typed_data';

/// CSV → Classifier (V5.md §11.10) — the port of EXE db/csv-import.js and
/// the cell conversion in hub/csv-import.js. The first row is the field
/// names, the first column the object names, every other row an object.
///
/// Encoding: a CSV Excel saves on Thai Windows is the system code page,
/// windows-874, not UTF-8 — read as UTF-8 every Thai name is mojibake. So a
/// BOM decides; else strict UTF-8; else windows-874.
class CsvRead {
  final String encoding;
  final List<String> header;
  final List<List<String>> rows;
  final List<String> types;
  final bool truncated;
  const CsvRead(this.encoding, this.header, this.rows, this.types, this.truncated);
}

class CsvImport {
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRows = 5000;
  static const types = ['text', 'textarea', 'number', 'date', 'checkbox', 'skip'];

  /// windows-874 bytes 0x80–0xFF (the WHATWG table); null = unmapped.
  static final List<int?> _cp874 = () {
    final t = List<int?>.filled(128, null);
    t[0x80 - 0x80] = 0x20AC;
    t[0x85 - 0x80] = 0x2026;
    const q = [0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014];
    for (var i = 0; i < q.length; i++) {
      t[0x91 - 0x80 + i] = q[i];
    }
    t[0xA0 - 0x80] = 0x00A0;
    for (var b = 0xA1; b <= 0xDA; b++) {
      t[b - 0x80] = b - 0xA0 + 0x0E00;
    }
    for (var b = 0xDF; b <= 0xFB; b++) {
      t[b - 0x80] = b - 0xA0 + 0x0E00;
    }
    return t;
  }();

  static (String, String) decode(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) return (utf8.decode(b.sublist(3)), 'utf-8');
    if (b.length >= 2 && ((b[0] == 0xFF && b[1] == 0xFE) || (b[0] == 0xFE && b[1] == 0xFF))) {
      final le = b[0] == 0xFF;
      final units = [for (var i = 2; i + 1 < b.length; i += 2) le ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]];
      return (String.fromCharCodes(units), le ? 'utf-16le' : 'utf-16be');
    }
    try {
      return (const Utf8Decoder(allowMalformed: false).convert(b), 'utf-8');
    } on FormatException {
      return (String.fromCharCodes([for (final c in b) c < 0x80 ? c : (_cp874[c - 0x80] ?? 0xFFFD)]), 'windows-874');
    }
  }

  /// RFC 4180, plus ';' (where a comma is the decimal mark) and tabs — the
  /// delimiter the first line has most of. Quotes hold delimiters, newlines
  /// and "".
  static List<List<String>> parse(String text) {
    final nl = text.indexOf(RegExp(r'\r?\n'));
    final first = nl < 0 ? text : text.substring(0, nl);
    int count(String ch) => ch.allMatches(first).length;
    final delim = ([',', ';', '\t']..sort((a, b) => count(b) - count(a))).first;
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQ = false;
    void endRow() {
      row.add(field.toString());
      field.clear();
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQ) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQ = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"' && field.isEmpty) {
        inQ = true;
      } else if (c == delim) {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
        if (rows.length > maxRows) break;
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static final _bool = RegExp(r'^(true|false|yes|no|y|n|จริง|เท็จ|ใช่|ไม่ใช่|✓|✗)$', caseSensitive: false);
  static final _date = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

  /// From a column's non-empty values: all numbers → number, all true/false
  /// words → checkbox, all ISO dates → date, else text (textarea if long).
  static String guessType(Iterable<String> values) {
    final vs = [for (final v in values) if (v.trim().isNotEmpty) v.trim()];
    if (vs.isEmpty) return 'text';
    if (vs.every((v) => RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v.replaceAll(',', '')))) return 'number';
    if (vs.every(_bool.hasMatch)) return 'checkbox';
    if (vs.every(_date.hasMatch)) return 'date';
    return vs.any((v) => v.length > 80 || v.contains('\n')) ? 'textarea' : 'text';
  }

  /// The whole read; throws [FormatException] 'too_large' or 'empty'.
  static CsvRead read(Uint8List bytes) {
    if (bytes.length > maxBytes) throw const FormatException('too_large');
    final (text, enc) = decode(bytes);
    final rows = parse(text);
    if (rows.length < 2) throw const FormatException('empty');
    final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final header = [
      for (var i = 0; i < width; i++) (i < rows[0].length && rows[0][i].trim().isNotEmpty) ? rows[0][i].trim() : '#${i + 1}',
    ];
    final body = [
      for (final r in rows.skip(1).take(maxRows)) [for (var i = 0; i < width; i++) i < r.length ? r[i] : ''],
    ];
    final ts = [for (var i = 0; i < width; i++) i == 0 ? 'name' : guessType(body.map((r) => r[i]))];
    return CsvRead(enc, header, body, ts, rows.length - 1 > maxRows);
  }

  /// A cell as its field type stores it; null = leave empty.
  static Object? cell(String type, String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return switch (type) {
      'number' => s.replaceAll(',', ''),
      'checkbox' => RegExp(r'^(true|yes|y|จริง|ใช่|✓|1)$', caseSensitive: false).hasMatch(s),
      'date' => switch (_date.firstMatch(s)) {
          final m? => '${int.parse(m[3]!)}/${int.parse(m[2]!)}/${int.parse(m[1]!)}',
          null => s,
        },
      _ => s,
    };
  }

  /// The bundle spec a CSV makes: one Classifier, no folder (EXE
  /// submitCsvImport). [types] per column; index 0 is the name.
  static Map<String, dynamic> spec(String name, CsvRead c, List<String> types) {
    final cols = <(int, String, String)>[];
    final seen = <String, int>{};
    for (var i = 1; i < c.header.length; i++) {
      if (types[i] == 'skip') continue;
      final n = (seen[c.header[i]] ?? 0) + 1;
      seen[c.header[i]] = n;
      // Two columns with one name would be one field — number the repeats.
      cols.add((i, n > 1 ? '${c.header[i]} ($n)' : c.header[i], types[i]));
    }
    return {
      'name': name,
      'folder': false,
      'modules': [
        {
          'kind': 'classifier',
          'name': name,
          'fields': [for (final (_, n, t) in cols) {'name': n, 'type': t}],
          'objects': [
            for (final r in c.rows)
              if (r[0].trim().isNotEmpty)
                {
                  'name': r[0].trim(),
                  'values': {
                    for (final (i, n, t) in cols)
                      if (cell(t, r[i]) case final Object v) n: v,
                  },
                },
          ],
        },
      ],
    };
  }
}

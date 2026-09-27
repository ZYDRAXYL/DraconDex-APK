import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/entity/entity_kinds.dart';
import '../assets/asset_store.dart';
import 'doc_model.dart';

/// A module as a document — the port of EXE db/doc-source.js (Procress 14,
/// APP docs/EXPORT-DECOR.md E2/E5). What DOCX, EPUB, HTML and PDF write,
/// read once from the vault: a title, the cover (the page title's cover, by
/// sha256), the module page's own pictures and text, and sections in
/// reading order — each a heading, an optional line under it, its page's
/// pictures, a property table, and its text.
///
///   author       a section per chapter, in order, a page break between
///   classifier   a section per element: its fields as a table, its note
///   chronicler   a section per event, its timeline and dates under it
///   drafter,     the module's own text
///   inspector
///
/// Any other kind (for PDF and HTML, which draw every page) is its
/// description plus the text and heading blocks of its page.
class DocSection {
  final String key, title;
  final String? sub;
  final List<int> images;
  final List<(String, String)> props;
  final List<DocBlock> blocks;
  final bool breakBefore;
  const DocSection(
    this.key,
    this.title, {
    this.sub,
    this.images = const [],
    this.props = const [],
    this.blocks = const [],
    this.breakBefore = false,
  });
}

class ModuleDocument {
  final String title, kind;
  final int? cover;
  final List<int> introImages;
  final List<DocBlock> introBlocks;
  final List<DocSection> sections;
  const ModuleDocument(this.title, this.kind, this.cover, this.introImages, this.introBlocks, this.sections);

  /// Every picture the document shows, in order.
  Iterable<int> get allImages sync* {
    if (cover != null) yield cover!;
    yield* introImages;
    for (final s in sections) {
      yield* s.images;
    }
  }

  /// Only one element's page (an element page's export).
  ModuleDocument only(String key) => ModuleDocument(title, kind, null, const [], const [], [
    for (final s in sections)
      if (s.key == key) s,
  ]);

  /// Only the module page — no element sections.
  ModuleDocument get pageOnly => ModuleDocument(title, kind, cover, introImages, introBlocks, const []);
}

const docKinds = {'author', 'classifier', 'chronicler', 'drafter', 'inspector'};

Future<List<int>> _imagesOf(DatabaseExecutor db, int moduleId, String? itemKey) async {
  final rows = itemKey == null
      ? await db.rawQuery(
          "SELECT source_key FROM page_block WHERE module_ref=? AND item_key IS NULL AND block_type='image' ORDER BY block_order, id",
          [moduleId],
        )
      : await db.rawQuery(
          "SELECT source_key FROM page_block WHERE module_ref=? AND item_key=? AND block_type='image' ORDER BY block_order, id",
          [moduleId, itemKey],
        );
  return [
    for (final r in rows)
      if (RegExp(r'^file_(\d+)$').firstMatch('${r['source_key'] ?? ''}') case final m?) int.parse(m[1]!),
  ];
}

Future<int?> _coverOf(DatabaseExecutor db, int moduleId, int nexusId) async {
  final r = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='pageHead'", [moduleId]);
  String? sha;
  try {
    final v = jsonDecode(r.isEmpty ? 'null' : '${r.first['ui_value'] ?? 'null'}');
    if (v is Map && v['cover'] is String) sha = v['cover'] as String;
  } catch (_) {}
  if (sha == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) return null;
  final f = await db.rawQuery('SELECT id FROM import_file WHERE nexus_ref=? AND sha256=? ORDER BY id LIMIT 1', [nexusId, sha]);
  return f.isEmpty ? null : f.first['id'] as int;
}

String _dateText(Map<String, Object?> r, String p) =>
    r['${p}_years'] == null ? '' : '${r['${p}_years']}.${'${r['${p}_month']}'.padLeft(2, '0')}.${'${r['${p}_day']}'.padLeft(2, '0')}';

/// The page's own text and headings, for a kind with no document shape.
Future<List<DocBlock>> _pageText(DatabaseExecutor db, int moduleId) async {
  final rows = await db.rawQuery(
    "SELECT block_type, content, config FROM page_block WHERE module_ref=? AND item_key IS NULL AND block_type IN ('text','heading') ORDER BY block_order, id",
    [moduleId],
  );
  final out = <DocBlock>[];
  for (final r in rows) {
    final text = '${r['content'] ?? ''}';
    if (text.trim().isEmpty) continue;
    if (r['block_type'] == 'heading') {
      var level = 2;
      try {
        final c = jsonDecode('${r['config'] ?? '{}'}');
        if (c is Map && c['level'] is int) level = (c['level'] as int).clamp(1, 6);
      } catch (_) {}
      out.add(DocBlock(BlockKind.h, level: level, runs: inlineRuns(text)));
    } else {
      out.addAll(toBlocks(text));
    }
  }
  return out;
}

Future<ModuleDocument?> moduleDocument(DatabaseExecutor db, int moduleId, {bool anyKind = false}) async {
  final mr = await db.rawQuery('SELECT id, nexus_ref, name, kind, description FROM module WHERE id=?', [moduleId]);
  if (mr.isEmpty) return null;
  final m = mr.first;
  final kind = m['kind'] as String;
  if (!docKinds.contains(kind) && !anyKind) return null;
  final nexusId = m['nexus_ref'] as int;
  final sections = <DocSection>[];
  var intro = <DocBlock>[];

  if (kind == 'author') {
    final rows = await db.rawQuery(
      'SELECT id, name, chapter_label, chapter_content FROM book_chapter WHERE module_ref=? ORDER BY chapter_order, id',
      [moduleId],
    );
    for (var i = 0; i < rows.length; i++) {
      final c = rows[i];
      final label = c['chapter_label'] as String?;
      sections.add(
        DocSection(
          'bchp_${c['id']}',
          label != null && label.isNotEmpty ? '$label. ${c['name']}' : '${c['name']}',
          images: await _imagesOf(db, moduleId, 'bchp_${c['id']}'),
          blocks: toBlocks(c['chapter_content'] as String?),
          breakBefore: i > 0,
        ),
      );
    }
  } else if (kind == 'classifier') {
    final vals = <int, Map<int, String?>>{};
    for (final r in await db.rawQuery(
      'SELECT a.object_ref, a.template_ref, a.attribute_value FROM classifier_attribute a JOIN classifier_object o ON a.object_ref=o.id WHERE o.module_ref=?',
      [moduleId],
    )) {
      (vals[r['object_ref'] as int] ??= {})[r['template_ref'] as int] = r['attribute_value'] as String?;
    }
    for (final o in await db.rawQuery('SELECT id, name, note FROM classifier_object WHERE module_ref=? ORDER BY display_order, id', [
      moduleId,
    ])) {
      final oid = o['id'] as int;
      final props = <(String, String)>[];
      for (final tp in await db.rawQuery(
        'SELECT id, description, attribute_type FROM classifier_template WHERE module_ref=? AND (object_ref IS NULL OR object_ref=?) ORDER BY display_order, id',
        [moduleId, oid],
      )) {
        final type = tp['attribute_type'] as String? ?? 'text';
        if (type == 'formula') continue; // computed in the app — nothing stored to write
        var val = vals[oid]?[tp['id'] as int] ?? '';
        if (type == 'relation') {
          final names = <String>[];
          for (final r in await db.rawQuery('SELECT to_key FROM entity_relation WHERE from_key=? AND rel_type=? ORDER BY id', [
            'cobj_$oid',
            'ctpl_${tp['id']}',
          ])) {
            final n = await EntityKinds.nameOf(db, r['to_key'] as String);
            if (n != null) names.add(n);
          }
          val = names.join(', ');
        } else if (type == 'checkbox') {
          val = val == '1' ? '✓' : (val.isEmpty ? '' : '✗');
        } else if (type == 'multi') {
          try {
            final a = jsonDecode(val);
            if (a is List) val = a.join(', ');
          } catch (_) {}
        }
        if (val.trim().isNotEmpty) props.add(('${tp['description']}', val));
      }
      sections.add(
        DocSection(
          'cobj_$oid',
          '${o['name']}',
          images: await _imagesOf(db, moduleId, 'cobj_$oid'),
          props: props,
          blocks: toBlocks(o['note'] as String?),
        ),
      );
    }
  } else if (kind == 'chronicler') {
    final rows = await db.rawQuery(
      '''
      SELECT te.id, te.event_name, te.story, tl.line_name,
        s.day s_day, s.month s_month, s.years s_years, e.day e_day, e.month e_month, e.years e_years
      FROM timeline_event te JOIN timeline tl ON te.timeline_id=tl.id
      LEFT JOIN timeline_date s ON te.start_at=s.id LEFT JOIN timeline_date e ON te.end_at=e.id
      WHERE tl.module_ref=? ORDER BY s.years, s.month, s.day, te.id''',
      [moduleId],
    );
    for (final e in rows) {
      final when = [_dateText(e, 's'), _dateText(e, 'e')].where((s) => s.isNotEmpty).join(' – ');
      final name = e['event_name'] as String?;
      sections.add(
        DocSection(
          'tlev_${e['id']}',
          name != null && name.isNotEmpty ? name : when,
          sub: [e['line_name'] as String? ?? '', when].where((s) => s.isNotEmpty).join(' · '),
          images: await _imagesOf(db, moduleId, 'tlev_${e['id']}'),
          blocks: toBlocks(e['story'] as String?),
        ),
      );
    }
  } else if (kind == 'drafter' || kind == 'inspector') {
    intro = toBlocks(m['description'] as String?);
  } else {
    intro = [...toBlocks(m['description'] as String?), ...await _pageText(db, moduleId)];
  }
  return ModuleDocument('${m['name']}', kind, await _coverOf(db, moduleId, nexusId), await _imagesOf(db, moduleId, null), intro, sections);
}

// ── the pictures ────────────────────────────────────────────────────────
class MediaBytes {
  final Uint8List data;
  final String ext; // png · jpg · gif · webp · svg
  final String name;
  const MediaBytes(this.data, this.ext, this.name);
  String get mime =>
      const {'png': 'image/png', 'jpg': 'image/jpeg', 'gif': 'image/gif', 'webp': 'image/webp', 'svg': 'image/svg+xml'}[ext]!;
}

/// What the bytes are, by their own header — on the web a picture's stored
/// bytes are its PNG proxy whatever the file was called.
String? sniffImage(Uint8List b) {
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) return 'png';
  if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) return 'jpg';
  if (b.length >= 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'gif';
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'webp';
  }
  final head = utf8.decode(b.sublist(0, b.length < 256 ? b.length : 256), allowMalformed: true).trimLeft();
  if (head.startsWith('<svg') || (head.startsWith('<?xml') && head.contains('<svg'))) return 'svg';
  return null;
}

/// The pictures [ids] name, read once, in a format [allow] lists — a file
/// that is gone, not a picture, or in another format is left out (and
/// counted by the caller as missing).
Future<Map<int, MediaBytes>> loadMedia(DatabaseExecutor db, Iterable<int> ids, Set<String> allow) async {
  final out = <int, MediaBytes>{};
  for (final id in ids.toSet()) {
    final a = await AssetStore.get(db, id);
    if (a == null || a.isUrl) continue;
    var bytes = await AssetStore.bytesOf(a);
    var ext = bytes == null ? null : sniffImage(bytes);
    if ((ext == null || !allow.contains(ext)) && a.proxy != null && sniffImage(a.proxy!) == 'png' && allow.contains('png')) {
      bytes = a.proxy; // e.g. a WebP where only PNG/JPEG/GIF go: its PNG proxy
      ext = 'png';
    }
    if (bytes == null || ext == null || !allow.contains(ext)) continue;
    final base = a.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    out[id] = MediaBytes(bytes, ext, base.isEmpty ? 'image' : base);
  }
  return out;
}

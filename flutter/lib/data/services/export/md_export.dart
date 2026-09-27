import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/entity/entity_kinds.dart';
import 'doc_source.dart';
import 'zip_writer.dart';

/// Export as Markdown — the port of EXE db/md-export.js (APP docs/V5.md
/// §11.4, EXPORT-DECOR.md E3). One .md file per entity, one folder per
/// module (the Nest's own tree), in a .zip:
///
///   Classifier object   YAML frontmatter of its fields, its note as the body
///   Author chapter      one file per chapter, in order; status/synopsis/POV
///   Drafter / Inspector the module's text as `<module>/<module>.md`
///   Chronicler event    one file per event, its dates in the frontmatter
///   Narrator dialogue   description, then the talk rows
///   Scribe session      the messages
///   Diviner table       its entries as a list, ranges or weights first
///   legacy notes        Notes/<title>.md (whole-Nexus export only)
///
/// A relation is `[[Name]]` in the frontmatter, and every [[wikilink]] in the
/// text is left exactly as written — Obsidian reads both as links as-is.
/// [moduleId] exports one module and everything inside it; the pictures a
/// page shows travel as files in assets/, embedded as ![[assets/…]].
class MdExport {
  final List<ZipEntry> entries;
  final int files, pictures, missing;
  const MdExport(this.entries, this.files, this.pictures, this.missing);
}

String safeName(Object? s, [String fallback = 'untitled']) {
  var v = '${s ?? ''}'.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
  if (v.isEmpty) v = fallback;
  return v.length > 120 ? v.substring(0, 120) : v;
}

/// Any YAML scalar as JSON: a double-quoted JSON string is valid YAML, and it
/// survives colons, '#', leading dashes and Thai without special cases.
String _yv(Object v) => v is num || v is bool ? '$v' : jsonEncode('$v');
String _link(String name) => '[[$name]]';

String frontmatter(List<(String, Object?)> pairs) {
  final lines = <String>[];
  for (final (k, v) in pairs) {
    if (v == null || v == '' || (v is List && v.isEmpty)) continue;
    final key = RegExp(r'^[\p{L}\p{N}_ -]+$', unicode: true).hasMatch(k) && !RegExp(r'^\s|\s$').hasMatch(k) ? k : jsonEncode(k);
    if (v is List) {
      lines.add('$key:');
      for (final it in v) {
        lines.add('  - ${_yv(it as Object)}');
      }
    } else {
      lines.add('$key: ${_yv(v)}');
    }
  }
  return lines.isEmpty ? '' : '---\n${lines.join('\n')}\n---\n\n';
}

String? _fmtDate(Map<String, Object?>? r) =>
    r == null || r['years'] == null ? null : '${r['years']}-${'${r['month']}'.padLeft(2, '0')}-${'${r['day']}'.padLeft(2, '0')}';

/// → the zip's entries, or null when there is nothing to write.
Future<MdExport?> markdownEntries(DatabaseExecutor db, int nexusId, {int? moduleId}) async {
  final nx = await db.rawQuery('SELECT name FROM nexus WHERE id=?', [nexusId]);
  Map<String, Object?>? scopeMod;
  if (moduleId != null) {
    final r = await db.rawQuery('SELECT name FROM module WHERE id=? AND nexus_ref=?', [moduleId, nexusId]);
    if (r.isEmpty) return null;
    scopeMod = r.first;
  }
  final root = safeName(scopeMod != null ? scopeMod['name'] : (nx.isEmpty ? null : nx.first['name']), 'nexus');

  final nameCache = <String, String?>{};
  Future<String?> nameOf(String key) async =>
      nameCache.containsKey(key) ? nameCache[key] : (nameCache[key] = await EntityKinds.nameOf(db, key));

  var mods = await db.rawQuery(
    'SELECT id, parent_id, name, kind, handle, description FROM module WHERE nexus_ref=? ORDER BY display_order, id',
    [nexusId],
  );
  if (moduleId != null) {
    final inside = {moduleId};
    for (var grew = true; grew;) {
      grew = false;
      for (final m in mods) {
        if (!inside.contains(m['id']) && inside.contains(m['parent_id'])) {
          inside.add(m['id'] as int);
          grew = true;
        }
      }
    }
    mods = mods.where((m) => inside.contains(m['id'])).toList();
  }
  final byId = {for (final m in mods) m['id'] as int: m};
  final folderOf = <int, String?>{};
  final taken = <String, Set<String>>{};
  String unique(String folder, String base, [String ext = '']) {
    final set = taken.putIfAbsent(folder, () => <String>{});
    var name = base;
    for (var n = 2; set.contains('$name$ext'.toLowerCase()); n++) {
      name = '$base ($n)';
    }
    set.add('$name$ext'.toLowerCase());
    return '$name$ext';
  }

  String folder(Map<String, Object?> m) {
    final id = m['id'] as int;
    if (folderOf.containsKey(id)) return folderOf[id] ?? root;
    if (id == moduleId) return folderOf[id] = root;
    final pid = m['parent_id'] as int?;
    folderOf[id] = null; // cycle guard: a broken parent chain lands at the root
    final parent = pid != null && byId[pid] != null ? folder(byId[pid]!) : root;
    return folderOf[id] = '$parent/${unique(parent, safeName(m['name']))}';
  }

  for (final m in mods) {
    folder(m);
  }

  final entries = <ZipEntry>[];
  // Pictures: every image block on a page in scope, by the page's key.
  final pics = <String, List<int>>{};
  if (mods.isNotEmpty) {
    final rows = await db.rawQuery(
      "SELECT module_ref, item_key, source_key FROM page_block WHERE block_type='image' AND module_ref IN (${List.filled(mods.length, '?').join(',')}) ORDER BY block_order, id",
      [for (final m in mods) m['id']],
    );
    for (final r in rows) {
      final f = RegExp(r'^file_(\d+)$').firstMatch('${r['source_key'] ?? ''}');
      if (f == null || r['item_key'] == '*') continue;
      (pics[r['item_key'] as String? ?? 'module_${r['module_ref']}'] ??= []).add(int.parse(f[1]!));
    }
  }
  final media = await loadMedia(db, pics.values.expand((l) => l), mdPictureFormats);
  final assetName = <int, String?>{};
  var missing = 0;
  String? assetOf(int fileId) => assetName.putIfAbsent(fileId, () {
    final b = media[fileId];
    if (b == null) {
      missing++;
      return null;
    }
    final name = 'assets/$fileId-${safeName(b.name, 'image')}.${b.ext}';
    entries.add(ZipEntry('$root/$name', b.data));
    return name;
  });
  String embeds(String key) => (pics[key] ?? []).map(assetOf).whereType<String>().map((n) => '![[$n]]').join('\n\n');
  void add(String dir, String base, String text, [String? key]) {
    final pix = key != null ? embeds(key) : '';
    entries.add(
      ZipEntry(
        '$dir/${unique(dir, safeName(base), '.md')}',
        pix.isNotEmpty ? '$text${text.endsWith('\n') || text.isEmpty ? '' : '\n\n'}$pix\n' : text,
      ),
    );
  }

  Future<List<String>> relatedOf(String key) async {
    final out = <String>{};
    for (final r in await db.rawQuery(
      'SELECT from_key, to_key, rel_type FROM entity_relation WHERE nexus_ref=? AND (from_key=? OR to_key=?)',
      [nexusId, key, key],
    )) {
      if (RegExp(r'^ctpl_\d+$').hasMatch('${r['rel_type'] ?? ''}')) continue;
      final other = await nameOf('${r['from_key'] == key ? r['to_key'] : r['from_key']}');
      if (other != null) out.add(_link(other));
    }
    return out.toList();
  }

  String dirOf(Map<String, Object?> m) => folderOf[m['id']] ?? root;
  List<Map<String, Object?>> ofKind(String k) => mods.where((m) => m['kind'] == k).toList();

  // Drafter / Inspector: the module's own text; any other module with a
  // description keeps it as a folder note of the same name.
  for (final m in mods) {
    final desc = m['description'] as String?;
    if ((desc == null || desc.isEmpty) && !['drafter', 'inspector'].contains(m['kind']) && !pics.containsKey('module_${m['id']}')) {
      continue;
    }
    add(
      dirOf(m),
      '${m['name']}',
      frontmatter([('kind', m['kind']), ('handle', m['handle']), ('related', await relatedOf('module_${m['id']}'))]) + (desc ?? ''),
      'module_${m['id']}',
    );
  }

  for (final m in ofKind('classifier')) {
    for (final o in await db.rawQuery('SELECT id, name, note FROM classifier_object WHERE module_ref=? ORDER BY display_order, id', [
      m['id'],
    ])) {
      final oid = o['id'] as int;
      final vals = {
        for (final v in await db.rawQuery('SELECT template_ref, attribute_value FROM classifier_attribute WHERE object_ref=?', [oid]))
          v['template_ref'] as int: v['attribute_value'] as String?,
      };
      final pairs = <(String, Object?)>[('category', _link('${m['name']}'))];
      for (final tp in await db.rawQuery(
        'SELECT id, description, attribute_type, options FROM classifier_template WHERE module_ref=? AND (object_ref IS NULL OR object_ref=?) ORDER BY display_order, id',
        [m['id'], oid],
      )) {
        final raw = vals[tp['id']];
        final type = tp['attribute_type'] as String? ?? 'text';
        Object? v;
        if (type == 'relation') {
          final names = <String>[];
          for (final r in await db.rawQuery('SELECT to_key FROM entity_relation WHERE from_key=? AND rel_type=? ORDER BY id', [
            'cobj_$oid',
            'ctpl_${tp['id']}',
          ])) {
            final n = await nameOf('${r['to_key']}');
            if (n != null) names.add(_link(n));
          }
          v = names;
        } else if (type == 'formula') {
          var expr = '';
          try {
            final o2 = jsonDecode('${tp['options'] ?? '{}'}');
            if (o2 is Map && o2['expr'] is String) expr = o2['expr'] as String;
          } catch (_) {}
          v = expr.isNotEmpty ? '= $expr' : null;
        } else if (raw == null || raw.isEmpty) {
          v = null;
        } else if (type == 'multi') {
          try {
            final a = jsonDecode(raw);
            v = a is List ? a.map((e) => '$e').toList() : ['$a'];
          } catch (_) {
            v = [raw];
          }
        } else if (type == 'checkbox') {
          v = raw == '1';
        } else if (type == 'number' && num.tryParse(raw) != null) {
          v = num.parse(raw);
        } else {
          v = raw;
        }
        pairs.add(('${tp['description']}', v));
      }
      pairs.add(('related', await relatedOf('cobj_$oid')));
      add(dirOf(m), '${o['name']}', frontmatter(pairs) + (o['note'] as String? ?? ''), 'cobj_$oid');
    }
  }

  for (final m in ofKind('author')) {
    final rows = await db.rawQuery(
      'SELECT id, name, chapter_label, chapter_content, synopsis, status, pov_key FROM book_chapter WHERE module_ref=? ORDER BY chapter_order, id',
      [m['id']],
    );
    final width = '${rows.length}'.length;
    for (var i = 0; i < rows.length; i++) {
      final c = rows[i];
      final pov = c['pov_key'] != null ? await nameOf('${c['pov_key']}') : null;
      add(
        dirOf(m),
        '${'${i + 1}'.padLeft(width, '0')} ${c['name']}',
        frontmatter([
              ('book', _link('${m['name']}')),
              ('label', c['chapter_label']),
              ('status', c['status']),
              ('synopsis', c['synopsis']),
              ('pov', pov != null ? _link(pov) : null),
              ('related', await relatedOf('bchp_${c['id']}')),
            ]) +
            (c['chapter_content'] as String? ?? ''),
        'bchp_${c['id']}',
      );
    }
  }

  for (final m in ofKind('scribe')) {
    for (final s in await db.rawQuery('SELECT id, name FROM chat_session WHERE module_ref=? ORDER BY session_order, id', [m['id']])) {
      final msgs = await db.rawQuery('SELECT message, side FROM chat_message WHERE session_ref=? ORDER BY id', [s['id']]);
      add(
        dirOf(m),
        '${s['name']}',
        frontmatter([('related', await relatedOf('chss_${s['id']}'))]) +
            msgs
                .map((g) => g['side'] == 'l' ? '> ${'${g['message'] ?? ''}'.replaceAll('\n', '\n> ')}' : '${g['message'] ?? ''}')
                .join('\n\n'),
        'chss_${s['id']}',
      );
    }
  }

  for (final m in ofKind('chronicler')) {
    final rows = await db.rawQuery(
      '''
      SELECT te.id, te.event_name, te.story, te.start_at, te.end_at, tl.line_name FROM timeline_event te
      JOIN timeline tl ON te.timeline_id=tl.id WHERE tl.module_ref=? ORDER BY te.id''',
      [m['id']],
    );
    Future<Map<String, Object?>?> date(Object? id) async {
      if (id == null) return null;
      final r = await db.rawQuery('SELECT day, month, years FROM timeline_date WHERE id=?', [id]);
      return r.isEmpty ? null : r.first;
    }

    for (final e in rows) {
      final start = _fmtDate(await date(e['start_at']));
      final end = _fmtDate(await date(e['end_at']));
      final name = e['event_name'] as String?;
      add(
        dirOf(m),
        name != null && name.isNotEmpty ? name : (start ?? 'event'),
        frontmatter([('timeline', e['line_name']), ('start', start), ('end', end), ('related', await relatedOf('tlev_${e['id']}'))]) +
            (e['story'] as String? ?? ''),
        'tlev_${e['id']}',
      );
    }
  }

  for (final m in ofKind('narrator')) {
    for (final g in await db.rawQuery('SELECT id, name, description FROM story_dialogue WHERE module_ref=? ORDER BY id', [m['id']])) {
      final lines = <String>[];
      for (final r in await db.rawQuery(
        'SELECT speaker, linker_key, talk_sentence FROM story_talk WHERE dialogue_ref=? ORDER BY talk_order, id',
        [g['id']],
      )) {
        final who = r['linker_key'] != null ? await nameOf('${r['linker_key']}') : null;
        final sp = who != null ? _link(who) : r['speaker'] as String?;
        lines.add(sp != null && sp.isNotEmpty ? '**$sp:** ${r['talk_sentence'] ?? ''}' : '${r['talk_sentence'] ?? ''}');
      }
      add(
        dirOf(m),
        '${g['name']}',
        frontmatter([('related', await relatedOf('sdlg_${g['id']}'))]) +
            [g['description'] as String? ?? '', lines.join('\n\n')].where((s) => s.isNotEmpty).join('\n\n'),
      );
    }
  }

  for (final m in ofKind('diviner')) {
    for (final tb in await db.rawQuery('SELECT id, name, dice, mode FROM diviner_table WHERE module_ref=? ORDER BY display_order, id', [
      m['id'],
    ])) {
      final lines = <String>[];
      for (final e in await db.rawQuery(
        'SELECT weight, range_lo, range_hi, entry_text, linker_key FROM diviner_entry WHERE table_ref=? ORDER BY display_order, id',
        [tb['id']],
      )) {
        final nm = e['linker_key'] != null ? await nameOf('${e['linker_key']}') : null;
        final text = [e['entry_text'] as String?, nm != null ? _link(nm) : null].whereType<String>().where((s) => s.isNotEmpty).join(' ');
        final dice = tb['dice'] as String?;
        final lead = tb['mode'] == 'join'
            ? ''
            : dice != null && dice.isNotEmpty && e['range_lo'] != null
            ? '${e['range_lo']}${e['range_hi'] != null && e['range_hi'] != e['range_lo'] ? '–${e['range_hi']}' : ''}: '
            : (dice == null || dice.isEmpty)
            ? '(${e['weight']}) '
            : '';
        lines.add('- $lead$text');
      }
      add(
        dirOf(m),
        '${tb['name']}',
        frontmatter([('dice', tb['dice']), ('mode', tb['mode'] == 'join' ? 'join' : null)]) + lines.join('\n'),
      );
    }
  }

  if (moduleId == null) {
    for (final n in await db.rawQuery('SELECT title, content FROM note WHERE nexus_ref=? ORDER BY id', [nexusId])) {
      add('$root/Notes', '${n['title']}', n['content'] as String? ?? '');
    }
  }

  final files = entries.where((e) => e.name.endsWith('.md')).length;
  if (files == 0) return null;
  return MdExport(entries, files, assetName.values.whereType<String>().length, missing);
}

/// Any picture a Markdown reader shows.
const mdPictureFormats = {'png', 'jpg', 'gif', 'webp', 'svg'};

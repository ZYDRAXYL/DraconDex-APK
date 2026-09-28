import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'assets/asset_store.dart';
import 'export/zip_writer.dart';
import 'vault_snapshot_service.dart';

/// `.dxpack` (APP docs/ASSET-PACK.md): the modules the user sorted into
/// folders on the phone, with every file filed in them, as one zip the
/// desktop turns back into the same folders on disk — the way a Unity
/// `.unitypackage` carries a slice of `Assets/`:
///
///     pack.json      the manifest — every asset and the module it is filed in
///     snapshot.json  the v2 snapshot a .mddx carries (VaultSnapshotService)
///     Assets/…       the files, laid out by the collector tree
///
/// The layout under Assets/ is for people; the manifest is the truth. EXE
/// (db/asset-pack.js) files each asset by its moduleId — like a Unity .meta
/// GUID — never by the folder it sits in here, and lays the folders out with
/// its own mirror plan. The folder names below follow that same plan
/// ([dirNameOf], [planFolders]) so what you see in the zip is what you get.
class AssetPack {
  static const format = 'dracondex-asset-pack';
  static const version = 1;

  /// [moduleId] scopes the pack to that module and everything under it (the
  /// .mddx scope); null packs the whole Nexus, unfiled assets included.
  static Future<AssetPackResult?> export(Database db, int nexusId, {int? moduleId, String? appVersion}) async {
    final ids = moduleId == null ? null : await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, moduleId);
    final snapshot = await VaultSnapshotService.serializeVault(db, nexusId, moduleIds: ids, appVersion: appVersion);
    if (snapshot == null) return null;

    final mods = await db.rawQuery(
        'SELECT id, parent_id, name, kind, display_order FROM module WHERE nexus_ref=?', [nexusId]);
    final dirOf = planFolders(mods);
    final parentOf = {for (final m in mods) m['id'] as int: m['parent_id'] as int?};
    // An asset filed in a non-collector sits in its nearest collector's
    // folder (a module is a file on the desktop, not a folder).
    String folderOf(int? id) {
      for (int? m = id; m != null; m = parentOf[m]) {
        final d = dirOf[m];
        if (d != null) return d;
      }
      return '';
    }

    final scope = ids?.toSet();
    final rows = await db.rawQuery(
      'SELECT id, file_name, file_path, file_type, file_size, source_kind, proxy, module_ref, sha256 '
      "FROM import_file WHERE nexus_ref=? AND source_kind='file' ORDER BY id",
      [nexusId],
    );
    final entries = <ZipEntry>[];
    final assets = <Map<String, Object?>>[];
    final used = <String>{};
    var missing = 0;
    for (final r in rows) {
      final ref = r['module_ref'] as int?;
      if (scope != null && (ref == null || !scope.contains(ref))) continue;
      final a = Asset.fromRow(r);
      final bytes = await AssetStore.bytesOf(a);
      final sha = r['sha256'] as String?;
      final quality = bytes == null ? 'none' : (sha != null && sha256.convert(bytes).toString() == sha ? 'full' : 'proxy');
      String? zip;
      if (bytes != null) {
        final dir = folderOf(ref);
        var name = dirNameOf(a.name.split(RegExp(r'[\\/]')).last);
        String at(String n) => 'Assets/${dir.isEmpty ? '' : '$dir/'}$n';
        if (used.contains(at(name).toLowerCase())) name = '${a.id}-$name';
        zip = at(name);
        used.add(zip.toLowerCase());
        entries.add(ZipEntry(zip, bytes, store: true));
      } else {
        missing++;
      }
      assets.add({
        'id': a.id,
        'moduleId': ref,
        'name': a.name,
        'type': a.type,
        'size': a.size,
        'sha256': sha,
        'quality': quality,
        'zip': zip,
      });
    }

    final pack = {
      'format': format,
      'version': version,
      'app': appVersion == null ? 'dracondex-apk' : 'dracondex-apk $appVersion',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': {'moduleId': moduleId},
      'assets': assets,
    };
    final bytes = writeZip([
      ZipEntry('pack.json', const JsonEncoder.withIndent(' ').convert(pack)),
      ZipEntry('snapshot.json', jsonEncode(snapshot)),
      ...entries,
    ]);
    return AssetPackResult(bytes, files: entries.length, missing: missing);
  }
}

class AssetPackResult {
  final Uint8List bytes;
  final int files, missing;
  const AssetPackResult(this.bytes, {required this.files, required this.missing});
}

final _winReserved = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$', caseSensitive: false);

/// Collector name -> folder name: EXE db/mirror.js dirNameOf, character for
/// character, so a folder here has the name the desktop will give it.
String dirNameOf(String? name) {
  var s = (name ?? '').replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').replaceAll(RegExp(r'[. ]+$'), '').trim();
  if (s.isEmpty || s == '.' || s == '..') s = '_';
  if (_winReserved.hasMatch(s)) s = '_$s';
  return s.length > 120 ? s.substring(0, 120) : s;
}

/// Collector id -> its folder path ('World/Maps'): EXE db/mirror.js
/// planMirror's walk — siblings by display_order then id, and a name that
/// clashes (case-insensitively, with a sibling folder or `.mddx` file) kept
/// apart by its id.
Map<int, String> planFolders(List<Map<String, Object?>> modules) {
  final byParent = <int?, List<Map<String, Object?>>>{};
  for (final m in modules) {
    (byParent[m['parent_id'] as int?] ??= []).add(m);
  }
  final out = <int, String>{};
  void walk(int? parent, String rel) {
    final kids = [...?byParent[parent]]
      ..sort((a, b) {
        final o = ((a['display_order'] as int?) ?? 0).compareTo((b['display_order'] as int?) ?? 0);
        return o != 0 ? o : (a['id'] as int).compareTo(b['id'] as int);
      });
    final used = <String>{};
    for (final m in kids) {
      final isDir = m['kind'] == 'collector';
      var base = dirNameOf(m['name'] as String?);
      String key(String b) => (isDir ? b : '$b.mddx').toLowerCase();
      if (used.contains(key(base))) base = '$base (${m['id']})';
      used.add(key(base));
      if (!isDir) continue;
      final p = rel.isEmpty ? base : '$rel/$base';
      out[m['id'] as int] = p;
      walk(m['id'] as int, p);
    }
  }

  walk(null, '');
  return out;
}

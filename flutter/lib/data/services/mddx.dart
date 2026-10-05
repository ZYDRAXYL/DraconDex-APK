import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'vault_snapshot_service.dart';

/// A module as files — the scoped snapshot EXE writes (db:exportModuleFile),
/// so a file from either app opens in the other.
///
/// Since APP Procress 16 part 3a it is a PAIR (SDB schema/FILE-FORMATS.md,
/// EXE src/db/module-files.js): `<name>.ddata` is the snapshot minus its page,
/// `<name>.dpage` is that snapshot's pageBlocks. One snapshot, split on write
/// and joined on read, so both go through the one import a `.mddx` (V5.md
/// §8.7, one file with its page inside) always took — and still takes.
class Mddx {
  static const fileVersion = 1;

  static ({Map<String, Object?> data, Map<String, Object?> page}) split(Map<String, Object?> snap) {
    final modules = snap['modules'] is List ? snap['modules'] as List : const [];
    return (
      data: {...snap, 'file': 'ddata', 'fileVersion': fileVersion, 'pageBlocks': const []},
      page: {
        'file': 'dpage',
        'fileVersion': fileVersion,
        'format': snap['format'],
        // which module(s) of the .ddata beside it these blocks belong to — informational
        'modules': [for (final m in modules) if (m is Map) {'id': m['id'], 'name': m['name'], 'kind': m['kind']}],
        'pageBlocks': snap['pageBlocks'] is List ? snap['pageBlocks'] : const [],
      },
    );
  }

  static Map<String, Object?> join(Map<String, Object?> data, Map<String, Object?>? page) =>
      {...data, 'pageBlocks': page?['pageBlocks'] is List ? page!['pageBlocks'] : (data['pageBlocks'] ?? const [])};

  /// The pair's bytes, or null when the module is gone.
  static Future<({Uint8List data, Uint8List page})?> export(Database db, int nexusId, int moduleId, {String? appVersion}) async {
    final ids = await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, moduleId);
    final payload = await VaultSnapshotService.serializeVault(db, nexusId, moduleIds: ids, appVersion: appVersion);
    if (payload == null) return null;
    final p = split(payload);
    Uint8List enc(Object o) => Uint8List.fromList(utf8.encode(jsonEncode(o)));
    return (data: enc(p.data), page: enc(p.page));
  }

  /// Only pages picked: a `.dpage` has nothing to land on without its `.ddata`.
  static bool onlyPages(List<({String name, Uint8List bytes})> files) =>
      files.isNotEmpty && files.every((f) => f.name.toLowerCase().endsWith('.dpage'));

  /// Merges picked files in under [parentId] — a `.ddata` with the `.dpage`
  /// of the same name (or the one `.dpage` picked with it), or a `.mddx`.
  /// The new root module's id, or null when nothing picked is a module.
  static Future<int?> import(Database db, int nexusId, int? parentId, List<({String name, Uint8List bytes})> files) async {
    Map<String, Object?>? decode(Uint8List b) {
      try {
        final v = jsonDecode(utf8.decode(b, allowMalformed: true));
        return v is Map ? v.cast<String, Object?>() : null;
      } on FormatException {
        return null;
      }
    }

    String base(String n) => (n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n).toLowerCase();
    final read = [for (final f in files) (name: f.name, json: decode(f.bytes))];
    final pages = [for (final r in read) if (r.json?['file'] == 'dpage') r];
    final data = read.where((r) => r.json != null && r.json!['file'] != 'dpage' && r.json!['modules'] is List).firstOrNull;
    if (data == null) return null;
    final page = pages.where((p) => base(p.name) == base(data.name)).firstOrNull ?? (pages.length == 1 ? pages.single : null);
    final payload = join(data.json!, page?.json);

    final r = await VaultSnapshotService.importModuleSnapshot(db, nexusId, parentId, payload);
    if (!r.ok) return null;
    final mods = [for (final m in payload['modules'] as List) m as Map];
    final ids = {for (final m in mods) m['id']};
    final root = mods.where((m) => m['parentId'] == null || !ids.contains(m['parentId'])).firstOrNull;
    return root == null ? null : r.keyMaps['module']?[root['id']];
  }
}

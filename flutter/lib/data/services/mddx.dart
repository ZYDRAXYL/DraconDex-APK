import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'vault_snapshot_service.dart';

/// `.mddx` (V5.md §8.7): one module and everything under it, as the scoped
/// snapshot EXE writes (db:exportModuleFile) — the same file the desktop's
/// folder mirror writes, so a file from either app opens in the other.
class Mddx {
  static Future<Uint8List?> export(Database db, int nexusId, int moduleId, {String? appVersion}) async {
    final ids = await VaultSnapshotService.collectModuleSubtreeIds(db, nexusId, moduleId);
    final payload = await VaultSnapshotService.serializeVault(db, nexusId, moduleIds: ids, appVersion: appVersion);
    return payload == null ? null : Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  /// Merges a picked file in under [parentId]; the new root module's id, or
  /// null when the file is not a module snapshot.
  static Future<int?> import(Database db, int nexusId, int? parentId, Uint8List bytes) async {
    Object? payload;
    try {
      payload = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      return null;
    }
    if (payload is! Map || payload['modules'] is! List) return null;
    final r = await VaultSnapshotService.importModuleSnapshot(db, nexusId, parentId, payload);
    if (!r.ok) return null;
    final mods = [for (final m in payload['modules'] as List) m as Map];
    final ids = {for (final m in mods) m['id']};
    final root = mods.where((m) => m['parentId'] == null || !ids.contains(m['parentId'])).firstOrNull;
    return root == null ? null : r.keyMaps['module']?[root['id']];
  }
}

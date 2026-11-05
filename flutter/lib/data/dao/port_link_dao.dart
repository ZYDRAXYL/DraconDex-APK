import 'package:sqflite/sqflite.dart';

/// A local Nexus and its clone on a portable drive (Plan part 9.2;
/// `lib/core/database/port_link_schema.dart`). Same meaning as EXE's
/// `port_link` row, plus where the drive is ([treeUri]).
class PortLink {
  final String linkUid;
  final int nexusId;
  final String treeUri;
  final String driveUid;
  final int driveNexusId;
  final String basePath;
  final String? localSig;
  final String? driveSig;
  final String? lastSyncAt;

  const PortLink({
    required this.linkUid,
    required this.nexusId,
    required this.treeUri,
    required this.driveUid,
    required this.driveNexusId,
    required this.basePath,
    this.localSig,
    this.driveSig,
    this.lastSyncAt,
  });

  factory PortLink.fromRow(Map<String, Object?> r) => PortLink(
        linkUid: r['link_uid']! as String,
        nexusId: r['nexus_ref']! as int,
        treeUri: r['tree_uri']! as String,
        driveUid: r['drive_uid']! as String,
        driveNexusId: r['drive_nexus_id']! as int,
        basePath: r['base_path']! as String,
        localSig: r['local_sig'] as String?,
        driveSig: r['drive_sig'] as String?,
        lastSyncAt: r['last_sync_at'] as String?,
      );
}

/// The link rows and the local id ↔ drive id map behind them.
///
/// The map is per table: [tbl] is the vault table name (`classifier_object`),
/// ids are that table's `id`. Join tables (no id) have no map — they are
/// matched by their columns, which are ids that are mapped.
class PortLinkDao {
  final DatabaseExecutor db;
  PortLinkDao(this.db);

  Future<void> insertLink(PortLink l) => db.insert('port_link', {
        'link_uid': l.linkUid,
        'nexus_ref': l.nexusId,
        'tree_uri': l.treeUri,
        'drive_uid': l.driveUid,
        'drive_nexus_id': l.driveNexusId,
        'base_path': l.basePath,
        'local_sig': l.localSig,
        'drive_sig': l.driveSig,
        'last_sync_at': l.lastSyncAt,
      });

  Future<List<PortLink>> listLinks() async =>
      (await db.query('port_link', orderBy: 'create_at, link_uid')).map(PortLink.fromRow).toList();

  Future<PortLink?> linkOf(int nexusId) async {
    final r = await db.query('port_link', where: 'nexus_ref = ?', whereArgs: [nexusId]);
    return r.isEmpty ? null : PortLink.fromRow(r.first);
  }

  Future<PortLink?> linkOfDrive(String driveUid, int driveNexusId) async {
    final r = await db.query('port_link', where: 'drive_uid = ? AND drive_nexus_id = ?', whereArgs: [driveUid, driveNexusId]);
    return r.isEmpty ? null : PortLink.fromRow(r.first);
  }

  /// After a sync: the new base and both sides' signatures.
  Future<void> markSynced(String linkUid, {required String basePath, String? localSig, String? driveSig}) => db.update(
        'port_link',
        {'base_path': basePath, 'local_sig': localSig, 'drive_sig': driveSig, 'last_sync_at': DateTime.now().toUtc().toIso8601String()},
        where: 'link_uid = ?',
        whereArgs: [linkUid],
      );

  /// Stop syncing. The row map goes with it (ON DELETE CASCADE); both copies
  /// of the Nexus stay. The base file is the caller's to delete.
  Future<void> deleteLink(String linkUid) => db.delete('port_link', where: 'link_uid = ?', whereArgs: [linkUid]);

  // ── the row map ─────────────────────────────────────────────────────────

  /// local id → drive id for one table.
  Future<Map<int, int>> localToDrive(String linkUid, String tbl) async => {
        for (final r in await db.query('port_rowmap', columns: ['local_id', 'drive_id'], where: 'link_uid = ? AND tbl = ?', whereArgs: [linkUid, tbl]))
          r['local_id']! as int: r['drive_id']! as int,
      };

  /// drive id → local id for one table.
  Future<Map<int, int>> driveToLocal(String linkUid, String tbl) async =>
      {for (final e in (await localToDrive(linkUid, tbl)).entries) e.value: e.key};

  /// Every table's map at once: tbl → (local id → drive id).
  Future<Map<String, Map<int, int>>> allMaps(String linkUid) async {
    final out = <String, Map<int, int>>{};
    for (final r in await db.query('port_rowmap', where: 'link_uid = ?', whereArgs: [linkUid])) {
      (out[r['tbl']! as String] ??= {})[r['local_id']! as int] = r['drive_id']! as int;
    }
    return out;
  }

  /// Replaces the whole map of a link — what absorb (9.3) writes after a merge,
  /// in the same transaction as the rows themselves. [maps]: tbl → (local → drive).
  Future<void> replaceMaps(String linkUid, Map<String, Map<int, int>> maps) async {
    await db.delete('port_rowmap', where: 'link_uid = ?', whereArgs: [linkUid]);
    final batch = db.batch();
    for (final t in maps.entries) {
      for (final e in t.value.entries) {
        batch.insert('port_rowmap', {'link_uid': linkUid, 'tbl': t.key, 'local_id': e.key, 'drive_id': e.value});
      }
    }
    await batch.commit(noResult: true);
  }
}

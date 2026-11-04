import 'package:sqflite/sqflite.dart';

/// Port Link on Android (APP Plan.md Procress 32 part 9.2) — this app's own
/// tables, kept in `novel-manager.db` beside the vault tables but NOT in the
/// shared vault.sql: like EXE's `nexus_file` / `port_link` (in its app.ddx),
/// they describe this install, not a world. `VaultUpgrade` only walks the
/// vendored tables, so it leaves these alone.
///
/// Why two tables where EXE has one: EXE keeps one `.ddx` per Nexus, so its
/// local file can carry the drive's row ids unchanged. Here every Nexus shares
/// one database and one id sequence per table — a drive row's id is very
/// likely taken by another Nexus's row. So a linked Nexus's rows keep ids of
/// this database, and `port_rowmap` remembers which drive row each one is.
/// Extract (Nexus → a vault file in the drive's ids, for the merge) reads it;
/// absorb (the merged file → this database) writes it (Plan part 9.3).
const List<String> portLinkCreateStatements = [
  '''
CREATE TABLE IF NOT EXISTS port_link (
  link_uid TEXT PRIMARY KEY,
  nexus_ref INTEGER NOT NULL UNIQUE REFERENCES nexus(id) ON DELETE CASCADE,
  -- the SAF tree of the portable app's folder (lib/core/platform/saf.dart)
  tree_uri TEXT NOT NULL,
  -- the drive's marker driveUid and the id in the DRIVE's registry
  drive_uid TEXT NOT NULL,
  drive_nexus_id INTEGER NOT NULL,
  -- this app's copy of the drive's vault file as of the last sync: the B of the merge
  base_path TEXT NOT NULL,
  -- "changed since the last sync?": drive = Saf.sig (size:mtime, as EXE);
  -- local = a fingerprint of the Nexus's rows (there is no file of its own here)
  local_sig TEXT,
  drive_sig TEXT,
  last_sync_at TEXT,
  create_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (drive_uid, drive_nexus_id)
)''',
  '''
CREATE TABLE IF NOT EXISTS port_rowmap (
  link_uid TEXT NOT NULL REFERENCES port_link(link_uid) ON DELETE CASCADE,
  tbl TEXT NOT NULL,
  local_id INTEGER NOT NULL,
  drive_id INTEGER NOT NULL,
  PRIMARY KEY (link_uid, tbl, local_id),
  UNIQUE (link_uid, tbl, drive_id)
)''',
];

/// Idempotent; run on every open (database_helper.dart) and by tests.
Future<void> ensurePortLinkTables(DatabaseExecutor db) async {
  for (final sql in portLinkCreateStatements) {
    await db.execute(sql);
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_factory.dart';
import 'file_export.dart';
import 'vault_schema.g.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._() {
    configureDatabaseFactory();
  }

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  // sqflite_common_ffi_web treats this as a logical IndexedDB store name,
  // not a real filesystem path — path_provider has no on-disk documents
  // directory to ask for on web anyway.
  Future<String> get databasePath async {
    if (kIsWeb) return 'dracondex.db';
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'novel-manager.db');
  }

  Future<Database> _open() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: vaultSchemaVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
      onUpgrade: _onUpgrade,
    );
  }

  // Runs on every open (fresh or existing). Idempotent ensure-step for every
  // vault table — same generated list _onCreate uses (vault_schema.g.dart,
  // shared with Electron, see src/schema/README.md) — so a device that
  // upgraded from an older build gets any table it's missing without a real
  // migration. onCreate already ran this once for a fresh install; running
  // it again here is a harmless no-op (CREATE TABLE IF NOT EXISTS).
  Future<void> _onOpen(Database db) async {
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    await _ensureDefaultNexus(db);
  }

  // vaultSchemaVersion only moves forward when src/schema/vault.sql changes
  // in a way that needs every existing install to re-run its init path — the
  // actual work for that is _onOpen's idempotent loop above (same pattern as
  // Electron's own initVaultDB), so there is nothing to do here beyond
  // existing.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // The Hub needs at least one Nexus to open into. Rather than forcing a
  // "create your first vault" step on mobile, seed one default Nexus the
  // first time this device has none (fresh install, or upgrading from a
  // pre-module-tree version).
  Future<void> _ensureDefaultNexus(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM nexus');
    final count = Sqflite.firstIntValue(rows) ?? 0;
    if (count == 0) {
      await db.insert('nexus', {'name': 'My Nexus'});
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    if (!kIsWeb) {
      // The web build's sqlite3.wasm has no shared-memory/multi-connection
      // story for WAL to coordinate over (each tab is its own worker) —
      // journal_mode stays at sqflite_common_ffi_web's default there.
      // rawQuery, not execute: unlike a plain PRAGMA set, `journal_mode=WAL`
      // and `busy_timeout=N` both always return the resulting value as a
      // result row even in assignment form, and Android's native sqflite
      // execute()/execSQL rejects any statement that returns rows ("Queries
      // can be performed using SQLiteDatabase query or rawQuery methods
      // only") — which was failing db open on every real Android install and
      // silently breaking every DB-backed feature, Nexus creation included.
      await db.rawQuery('PRAGMA journal_mode = WAL');
    }
    await db.rawQuery('PRAGMA busy_timeout = 5000');
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final sql in vaultCreateStatements) {
      await db.execute(sql);
    }
    await _seedDefaultColors(db);
    await _runMigrations(db);
  }

  Future<void> _seedDefaultColors(Database db) async {
    for (final code in defaultColorCodes) {
      await db.execute(
        'INSERT OR IGNORE INTO use_color (color_code) VALUES (?)',
        [code],
      );
    }
  }

  Future<void> _runMigrations(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(relation_type)');
    final hasColor = cols.any((c) => c['name'] == 'color');
    if (!hasColor) {
      try {
        await db.execute('ALTER TABLE relation_type ADD COLUMN color INTEGER REFERENCES use_color(id)');
      } catch (_) {}
    }

    final eventCols = await db.rawQuery('PRAGMA table_info(timeline_event)');
    final hasStory = eventCols.any((c) => c['name'] == 'story');
    if (!hasStory) {
      await db.execute('ALTER TABLE timeline_event ADD COLUMN story TEXT');
    }

    final objCols = await db.rawQuery('PRAGMA table_info(object)');
    final hasNote = objCols.any((c) => c['name'] == 'note');
    if (!hasNote) {
      try {
        await db.execute('ALTER TABLE object ADD COLUMN note TEXT');
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  Future<void> checkpoint() async {
    if (kIsWeb) return;
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  // Backup export/import needs a real file to hand to share_plus/file_picker
  // — there is no such file on web (data lives in IndexedDB inside the
  // browser). Callers should check kIsWeb before offering the feature; see
  // import_export_service.dart.
  Future<String> exportToTemp() async {
    if (kIsWeb) {
      throw UnsupportedError('exportToTemp is not supported on web.');
    }
    await checkpoint();
    final dbPath = await databasePath;
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final exportPath = join(tempDir.path, 'dracondex-backup-$stamp.db');
    await copyFileTo(dbPath, exportPath);
    return exportPath;
  }
}

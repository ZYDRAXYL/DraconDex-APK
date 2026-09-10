import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/temp_file.dart';
import 'google_auth_service.dart';
import 'import_export_service.dart';

/// Google Drive backup — the Flutter/PWA counterpart to the Electron app's
/// Drive backup (docs/DRIVE.md). Same shape: sign in with a Google account,
/// keep the backup in Drive's `appDataFolder` (a private per-app space the
/// rest of the user's Drive never shows), restore by merging rather than
/// overwriting.
///
/// Two separate slots, matching the two checkboxes on the Electron side:
///
/// * the database file — a byte-for-byte copy of the local .db, and so
///   **native only**: the web build keeps its database in IndexedDB through
///   sqflite_common_ffi_web and has no file to copy (DatabaseHelper
///   .exportToTemp throws on web for the same reason).
/// * the settings profile — theme, language and UI scale as JSON, which
///   every build target including the PWA can produce.
///
/// Authentication is not this file's business: GoogleAuthService owns the
/// login and hands over a bearer token (see google_auth_service.dart for why
/// that replaced google_sign_in).
class DriveBackupService {
  static const _databaseFileName = 'dracondex-backup.db';
  static const _settingsFileName = 'dracondex-settings.json';
  static const _lastBackupAtKey = 'drive_last_backup_at';
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

  /// The settings keys a profile carries — the same three the Electron app's
  /// "layout profile" backs up (theme / language / UI size), and deliberately
  /// a fixed list rather than "every stored key": the Google tokens and the
  /// Supabase key live in the same SharedPreferences store and must never
  /// leave the device inside a backup.
  static const _profileKeys = ['theme', 'locale', 'ui_scale'];

  /// False on the web/PWA build, where there is no database *file* to copy.
  static bool get databaseBackupSupported => !kIsWeb;

  static Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastBackupAtKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  /// Uploads the slots this build target can produce. Returns what it
  /// actually wrote so the caller can say "settings only" on web instead of
  /// implying the database went up too.
  static Future<DriveBackupOutcome> backupNow() async {
    final headers = await GoogleAuthService.authHeaders();

    await _upload(
      headers,
      _settingsFileName,
      'application/json',
      Uint8List.fromList(utf8.encode(jsonEncode(await _readProfile()))),
    );

    var database = false;
    if (databaseBackupSupported) {
      final exportPath = await DatabaseHelper.instance.exportToTemp();
      try {
        await _upload(
          headers,
          _databaseFileName,
          'application/octet-stream',
          await readFileBytes(exportPath),
        );
        database = true;
      } finally {
        await deleteTempFile(exportPath);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupAtKey, DateTime.now().toIso8601String());
    return DriveBackupOutcome(database: database, settings: true);
  }

  /// Downloads the database backup and merges it into the local database
  /// through the same path the manual "Import DB" menu uses — matching by
  /// name, never overwriting, exactly like docs/DRIVE.md §1.5.
  static Future<ImportSummary> restoreDatabase() async {
    if (!databaseBackupSupported) throw const DriveBackupException('unsupported');
    final headers = await GoogleAuthService.authHeaders();
    final bytes = await _download(headers, _databaseFileName);
    if (bytes == null) throw const DriveBackupException('no_backup');

    final path = await writeTempFile(_databaseFileName, bytes);
    try {
      return await ImportExportService.importFromFile(path);
    } finally {
      await deleteTempFile(path);
    }
  }

  /// Restores theme / language / UI scale. Returns false when no profile has
  /// ever been backed up, so the caller can say that rather than claim a
  /// restore that changed nothing.
  static Future<bool> restoreSettings() async {
    final headers = await GoogleAuthService.authHeaders();
    final bytes = await _download(headers, _settingsFileName);
    if (bytes == null) return false;

    Map<String, dynamic> profile;
    try {
      profile = (jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (_) {
      throw const DriveBackupException('bad_backup');
    }
    final values = profile['settings'];
    if (values is! Map) throw const DriveBackupException('bad_backup');

    final prefs = await SharedPreferences.getInstance();
    for (final key in _profileKeys) {
      final value = values[key];
      if (value is String) await prefs.setString(key, value);
      if (value is num) await prefs.setDouble(key, value.toDouble());
    }
    return true;
  }

  static Future<Map<String, dynamic>> _readProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final values = <String, Object?>{};
    for (final key in _profileKeys) {
      final value = prefs.get(key);
      if (value != null) values[key] = value;
    }
    return {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'settings': values,
    };
  }

  // -------------------------------------------------------------------------
  // Drive REST (appDataFolder space only)
  // -------------------------------------------------------------------------

  /// One fixed name per slot, overwritten every time — a single backup, no
  /// version history, same as the Electron side.
  static Future<void> _upload(
    Map<String, String> headers,
    String fileName,
    String contentType,
    Uint8List bytes,
  ) async {
    final id = await _findFileId(headers, fileName) ?? await _createEmptyFile(headers, fileName);
    final res = await _send(() => http.patch(
          Uri.parse('$_uploadUrl/$id').replace(queryParameters: {'uploadType': 'media'}),
          headers: {...headers, 'Content-Type': contentType},
          body: bytes,
        ));
    if (res.statusCode != 200) throw _driveError(res);
  }

  static Future<Uint8List?> _download(Map<String, String> headers, String fileName) async {
    final id = await _findFileId(headers, fileName);
    if (id == null) return null;
    final res = await _send(() => http.get(
          Uri.parse('$_filesUrl/$id').replace(queryParameters: {'alt': 'media'}),
          headers: headers,
        ));
    if (res.statusCode != 200) throw _driveError(res);
    return res.bodyBytes;
  }

  static Future<String?> _findFileId(Map<String, String> headers, String fileName) async {
    final uri = Uri.parse(_filesUrl).replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name='$fileName' and trashed=false",
      'fields': 'files(id)',
    });
    final res = await _send(() => http.get(uri, headers: headers));
    if (res.statusCode != 200) throw _driveError(res);
    final files = (jsonDecode(res.body)['files'] as List?) ?? const [];
    return files.isEmpty ? null : files.first['id'] as String;
  }

  static Future<String> _createEmptyFile(Map<String, String> headers, String fileName) async {
    final res = await _send(() => http.post(
          Uri.parse(_filesUrl),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': fileName,
            'parents': ['appDataFolder'],
          }),
        ));
    if (res.statusCode != 200) throw _driveError(res);
    return jsonDecode(res.body)['id'] as String;
  }

  static Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 60));
    } catch (e) {
      throw DriveBackupException('network', '$e');
    }
  }

  /// 401/403 mean the grant is the problem, not the request — worth telling
  /// apart so the UI can point at the account row instead of saying
  /// "backup failed" for a session that simply needs reconnecting.
  static DriveBackupException _driveError(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      return DriveBackupException('auth', 'HTTP ${res.statusCode}');
    }
    if (res.statusCode == 507) return const DriveBackupException('drive_full');
    return DriveBackupException('drive', 'HTTP ${res.statusCode}');
  }
}

/// What one backup run actually wrote.
class DriveBackupOutcome {
  final bool database;
  final bool settings;
  const DriveBackupOutcome({required this.database, required this.settings});
}

/// Failure codes the UI maps to localized text, in the same spirit as
/// GoogleAuthException: `network`, `auth`, `drive`, `drive_full`,
/// `no_backup`, `bad_backup`, `unsupported`.
class DriveBackupException implements Exception {
  final String code;
  final String? detail;
  const DriveBackupException(this.code, [this.detail]);

  @override
  String toString() => 'DriveBackupException($code${detail == null ? '' : ': $detail'})';
}

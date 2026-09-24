import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../wiki_service.dart';
import 'asset_files.dart';

/// Extension → asset class: the four classes the desktop switches on (EXE
/// db/asset-media.js ASSET_CLASS).
const assetClass = {
  'png': 'image', 'jpg': 'image', 'jpeg': 'image', 'gif': 'image', 'webp': 'image', 'svg': 'image', //
  'mp3': 'audio', 'wav': 'audio', 'ogg': 'audio', 'm4a': 'audio', 'flac': 'audio', //
  'mp4': 'video', 'webm': 'video', 'mov': 'video', 'mkv': 'video', //
  'md': 'doc', 'txt': 'doc', 'docx': 'doc', 'pdf': 'doc',
};

class Asset {
  final int id;
  final String name;
  final String path;
  final String type; // extension, or 'url'
  final int size;
  final bool isUrl;
  final Uint8List? proxy;
  final int? moduleRef;
  const Asset(this.id, this.name, this.path, this.type, this.size, this.isUrl, this.proxy, this.moduleRef);

  String? get cls => isUrl ? 'url' : assetClass[type];
  bool get isImage => cls == 'image';

  factory Asset.fromRow(Map<String, Object?> r) => Asset(
        r['id'] as int,
        r['file_name'] as String,
        r['file_path'] as String,
        (r['file_type'] as String? ?? '').toLowerCase(),
        r['file_size'] as int? ?? 0,
        r['source_kind'] == 'url',
        r['proxy'] as Uint8List?,
        r['module_ref'] as int?,
      );
}

/// The Asset Nest on the phone (V5.md §2, APK-V3.md §7): a picked file is
/// copied into the app's storage and gets an import_file row — name, type
/// (the extension, as the desktop derives it), size, sha256, and for an
/// image a small proxy the list and image blocks draw from. Assets stay on
/// this device: sync carries the row, never the file.
class AssetStore {
  /// The desktop's per-file proxy cap (asset-media.js PROXY_MAX_BYTES).
  static const proxyMaxBytes = 200 * 1024;

  /// On the web the proxy IS the file, so it may not be much bigger.
  static const webMaxBytes = 4 * 1024 * 1024;

  static Future<List<Asset>> list(DatabaseExecutor db, int nexusId) async => [
        for (final r in await db.rawQuery(
            'SELECT id, file_name, file_path, file_type, file_size, source_kind, proxy, module_ref FROM import_file '
            'WHERE nexus_ref=? ORDER BY id DESC',
            [nexusId]))
          Asset.fromRow(r),
      ];

  static Future<Asset?> get(DatabaseExecutor db, int id) async {
    final r = await db.rawQuery(
        'SELECT id, file_name, file_path, file_type, file_size, source_kind, proxy, module_ref FROM import_file WHERE id=?', [id]);
    return r.isEmpty ? null : Asset.fromRow(r.first);
  }

  /// A PNG no larger than [proxyMaxBytes], or null when it cannot be drawn.
  static Future<Uint8List?> makeProxy(Uint8List bytes, {int width = 480}) async {
    try {
      for (var w = width; w >= 60; w = (w * 0.7).round()) {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: w);
        final frame = await codec.getNextFrame();
        final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) return null;
        final out = png.buffer.asUint8List();
        if (out.length <= proxyMaxBytes) return out;
      }
    } catch (_) {}
    return null;
  }

  /// Adds a picked file; returns its id, or null when the web build cannot
  /// keep a file that big.
  static Future<int?> addFile(Database db, int nexusId, String fileName, Uint8List bytes, {int? moduleRef}) async {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final sha = sha256.convert(bytes).toString();
    final same = await db.rawQuery('SELECT id FROM import_file WHERE nexus_ref=? AND sha256=?', [nexusId, sha]);
    if (same.isNotEmpty) return same.first['id'] as int;
    final image = assetClass[ext] == 'image' && ext != 'svg';
    Uint8List? proxy;
    String? path;
    if (assetFilesOnDisk) {
      path = await storeAssetFile(nexusId, ext.isEmpty ? sha : '$sha.$ext', bytes);
      if (image) proxy = await makeProxy(bytes);
    } else {
      if (bytes.length > webMaxBytes) return null;
      path = 'web:$sha${ext.isEmpty ? '' : '.$ext'}';
      proxy = image ? (await makeProxy(bytes, width: 1200) ?? bytes) : bytes;
    }
    final id = await db.insert('import_file', {
      'nexus_ref': nexusId,
      'file_name': fileName,
      'file_path': path,
      'file_type': ext,
      'file_size': bytes.length,
      'module_ref': moduleRef,
      'sha256': sha,
      'proxy': proxy,
      'proxy_type': proxy == null ? null : (image ? 'image/png' : 'application/octet-stream'),
      'use_as_image': image ? 1 : 0,
    });
    await WikiService.resolveDangling(db, fileName, nexusId);
    return id;
  }

  /// A URL asset (§2.2): the URL in file_path, file_type 'url', size 0.
  static Future<int> addUrl(Database db, int nexusId, String url, String? name) async {
    final hit = await db.rawQuery('SELECT id FROM import_file WHERE nexus_ref=? AND file_path=?', [nexusId, url]);
    if (hit.isNotEmpty) return hit.first['id'] as int;
    return db.insert('import_file', {
      'nexus_ref': nexusId,
      'file_name': (name == null || name.isEmpty ? url : name).substring(0, (name == null || name.isEmpty ? url : name).length.clamp(0, 200)),
      'file_path': url,
      'file_type': 'url',
      'file_size': 0,
      'source_kind': 'url',
    });
  }

  static Future<void> rename(Database db, int id, String name) async {
    await db.rawUpdate('UPDATE import_file SET file_name=? WHERE id=?', [name, id]);
  }

  /// The row, and the stored copy — unless another row shares it.
  static Future<void> delete(Database db, int id) async {
    final a = await get(db, id);
    if (a == null) return;
    await db.delete('import_file', where: 'id=?', whereArgs: [id]);
    // An image block that showed it goes back to "choose an image".
    await db.rawUpdate("UPDATE page_block SET source_key=NULL WHERE source_key=? AND block_type='image'", ['file_$id']);
    final shared = await db.rawQuery('SELECT 1 FROM import_file WHERE file_path=?', [a.path]);
    if (!a.isUrl && shared.isEmpty) await deleteAssetFile(a.path);
  }

  /// The best bytes to draw: the stored file when there is one, else the proxy.
  static Future<Uint8List?> bytesOf(Asset a) async {
    if (a.isUrl) return null;
    if (assetFilesOnDisk && !a.path.startsWith('web:')) {
      final b = await readAssetFile(a.path);
      if (b != null) return b;
    }
    return a.proxy;
  }
}

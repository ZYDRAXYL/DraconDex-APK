import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Copies [bytes] to `<app documents>/assets/<nexus>/<name>` and returns the
/// path. [name] is the content hash plus extension, so the same file picked
/// twice is one file on disk.
Future<String?> storeAssetFile(int nexusId, String name, Uint8List bytes) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/assets/$nexusId');
  await dir.create(recursive: true);
  final f = File('${dir.path}/$name');
  if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

Future<Uint8List?> readAssetFile(String path) async {
  final f = File(path);
  return await f.exists() ? f.readAsBytes() : null;
}

Future<void> deleteAssetFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

bool get assetFilesOnDisk => true;

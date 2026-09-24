import 'dart:typed_data';

/// No filesystem: nothing is written; the caller keeps the bytes in the row.
Future<String?> storeAssetFile(int nexusId, String name, Uint8List bytes) async => null;

Future<Uint8List?> readAssetFile(String path) async => null;

Future<void> deleteAssetFile(String path) async {}

bool get assetFilesOnDisk => false;

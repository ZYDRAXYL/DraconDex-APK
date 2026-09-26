import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'asset_store.dart';

/// The stored copy through the system's "open with"; when no app takes it,
/// or the copy is gone, the share sheet with whatever bytes are left.
/// → false when there is nothing to hand over.
Future<bool> openAssetExternally(Asset a) async {
  if (!a.path.startsWith('web:') && await File(a.path).exists()) {
    final r = await OpenFilex.open(a.path, type: a.mime);
    if (r.type == ResultType.done) return true;
  }
  final bytes = await AssetStore.bytesOf(a);
  if (bytes == null) return false;
  await Share.shareXFiles([XFile.fromData(bytes, mimeType: a.mime, name: a.name)]);
  return true;
}

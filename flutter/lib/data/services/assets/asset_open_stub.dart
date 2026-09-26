import 'package:share_plus/share_plus.dart';

import 'asset_store.dart';

/// No filesystem and no "open with": the bytes go through the share sheet
/// (in a browser without one, share_plus downloads the file).
Future<bool> openAssetExternally(Asset a) async {
  final bytes = await AssetStore.bytesOf(a);
  if (bytes == null) return false;
  await Share.shareXFiles([XFile.fromData(bytes, mimeType: a.mime, name: a.name)]);
  return true;
}

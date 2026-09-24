// Where an Asset Nest file lives. On a phone the picked file is copied into
// the app's own storage; the web build has no filesystem (and `dart:io` does
// not compile there — docs/PWA.md §3), so there the proxy blob is the file.
export 'asset_files_stub.dart' if (dart.library.io) 'asset_files_io.dart';

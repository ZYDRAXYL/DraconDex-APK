// The local files around a Port Link sync — scratch copies, the base, asset
// files. Split like temp_file.dart: `dart:io` does not compile for the PWA
// (docs/PWA.md §3), and the PWA has no portable drive to sync with.
export 'portlink_files_stub.dart' if (dart.library.io) 'portlink_files_io.dart';

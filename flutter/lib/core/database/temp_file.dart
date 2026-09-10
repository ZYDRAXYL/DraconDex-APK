// Reading and writing scratch files around a Drive backup. Split the same
// way copyFileTo is (file_export.dart): the web build has no filesystem to
// implement these against, and `dart:io` is a compile-time error there, so
// the import must be conditional rather than guarded with kIsWeb — see
// docs/PWA.md §3.
export 'temp_file_stub.dart' if (dart.library.io) 'temp_file_io.dart';

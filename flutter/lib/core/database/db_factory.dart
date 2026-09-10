// Picks the right sqflite `databaseFactory` for the current platform.
// Native (mobile/desktop) already defaults to the right factory, so that
// side is a no-op; web has no native SQLite and needs databaseFactoryFfiWeb
// (sqflite_common_ffi_web) installed explicitly before the first
// openDatabase() call. Conditional export keeps dart:io out of the web
// build's compile graph — db_factory_web.dart never touches it.
export 'db_factory_stub.dart' if (dart.library.io) 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';

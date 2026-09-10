// Copies the on-disk database file to an export path. Only meaningful where
// there is a real filesystem — web's IndexedDB-backed store has no file to
// copy, so DatabaseHelper.exportToTemp() never calls this on web (see its
// kIsWeb guard) and the stub only exists to satisfy the conditional export.
export 'file_export_stub.dart' if (dart.library.io) 'file_export_io.dart';

// Downloads and installs a release APK. Android-only in practice (gated by
// isAndroidPlatform at the call site — see update_dialog.dart), but the
// split matters at compile time too: the io implementation uses dart:io's
// File, which is a hard compile error on web, so the export must never
// resolve to it there.
export 'apk_installer_stub.dart' if (dart.library.io) 'apk_installer_io.dart';

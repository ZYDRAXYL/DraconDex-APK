import 'package:open_filex/open_filex.dart';
import 'update_service.dart';

/// Mirrors apk_installer_io.dart's type so update_dialog.dart can catch it
/// without the web build having to reach into a dart:io-only library.
class ApkIntegrityException implements Exception {
  final String message;
  const ApkIntegrityException(this.message);
  @override
  String toString() => message;
}

Future<Object> downloadApk(
  UpdateAsset asset, {
  void Function(double progress)? onProgress,
  void Function()? onVerifying,
  String? expectedSha256,
}) {
  throw UnsupportedError('APK install is not available on the web version.');
}

Future<OpenResult> installApk(Object file) {
  throw UnsupportedError('APK install is not available on the web version.');
}

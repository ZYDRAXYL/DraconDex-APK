import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'update_service.dart';

/// A download that finished but produced a file we must not hand to the
/// package installer. Android's installer has exactly one message for a
/// truncated, corrupted, or otherwise unparseable APK ("มีปัญหาในการแยกวิเคราะห์
/// แพ็กเกจ" / "There was a problem parsing the package"), which tells the user
/// nothing about whether the build is broken or their download just got cut
/// off on a flaky connection. Catching it here is what makes the difference
/// explainable.
class ApkIntegrityException implements Exception {
  final String message;
  const ApkIntegrityException(this.message);
  @override
  String toString() => message;
}

/// Downloads [asset] to a temp file, reporting progress in [0, 1] when the
/// server sends a Content-Length. Throws on any failure — unlike
/// checkForUpdate() this is a user-initiated action (the user tapped
/// "Install now"), so silently doing nothing on failure would just look
/// broken; the caller (update_dialog.dart) surfaces the error instead.
///
/// The file is verified before it is returned: the byte count must match the
/// advertised Content-Length, and when [expectedSha256] is given (from the
/// release's checksums-sha256.txt — see UpdateService.fetchExpectedSha256)
/// the digest must match too. A file that fails either check is deleted
/// rather than left in the cache for a later attempt to find.
Future<File> downloadApk(
  UpdateAsset asset, {
  void Function(double progress)? onProgress,
  void Function()? onVerifying,
  String? expectedSha256,
}) async {
  final client = http.Client();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${asset.name}');
  try {
    final res = await client.send(http.Request('GET', Uri.parse(asset.downloadUrl))).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Download failed: HTTP ${res.statusCode}');
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }

    // A dropped connection does not always surface as a stream error: the
    // socket can close cleanly mid-body and leave a short, perfectly
    // well-formed-looking file behind.
    if (total > 0 && received != total) {
      throw ApkIntegrityException(
        'The download stopped early (${_mb(received)} of ${_mb(total)}). Check your connection and try again.',
      );
    }
    if (expectedSha256 != null) {
      onVerifying?.call();
      // Re-read from the local cache rather than hashing the network stream
      // in flight: it keeps this function's control flow to one concern per
      // step, and reading back what actually landed on disk is the stronger
      // check anyway.
      final actual = (await sha256.bind(file.openRead()).first).toString();
      if (actual != expectedSha256) {
        throw ApkIntegrityException(
          'The downloaded file does not match the checksum published with this release. Try again, or install from the release page.',
        );
      }
    }
    return file;
  } catch (_) {
    // Never leave a half-written APK in the cache — installApk() would
    // happily hand it to Android on a later attempt.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    rethrow;
  } finally {
    client.close();
  }
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Launches Android's package installer for a downloaded APK. Requires
/// android.permission.REQUEST_INSTALL_PACKAGES (declared in
/// AndroidManifest.xml) for the OS to even offer the "allow this app to
/// install unknown apps" flow; without it every attempt comes back
/// ResultType.permissionDenied. See update_dialog.dart for how the result
/// is surfaced to the user.
///
/// Android still refuses the install if the new APK's signing certificate
/// differs from the installed app's, whatever this returns — see
/// docs/UPDATE.md section 2.10 for why every release must be signed with the
/// same keystore.
Future<OpenResult> installApk(File file) => OpenFilex.open(file.path);

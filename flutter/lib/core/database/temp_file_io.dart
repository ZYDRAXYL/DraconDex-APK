import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();

/// Writes [bytes] into a fresh temporary directory and returns the file's
/// path. A directory of its own (not a shared temp name) so two restores
/// running at once cannot read each other's half-written file.
Future<String> writeTempFile(String fileName, Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('dracondex-drive');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Deletes a file written by [writeTempFile] along with the directory it was
/// given. Never throws: a leftover temp file is not worth failing a restore
/// that already succeeded.
Future<void> deleteTempFile(String path) async {
  try {
    final file = File(path);
    final dir = file.parent;
    await file.delete();
    if (dir.path.contains('dracondex-drive')) await dir.delete(recursive: true);
  } catch (_) {
    // ignored on purpose
  }
}

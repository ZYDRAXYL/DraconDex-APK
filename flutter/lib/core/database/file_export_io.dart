import 'dart:io';

Future<String> copyFileTo(String sourcePath, String destPath) async {
  await File(sourcePath).copy(destPath);
  return destPath;
}

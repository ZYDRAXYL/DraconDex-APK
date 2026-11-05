import 'dart:io';

import 'package:path_provider/path_provider.dart';

const portlinkFilesSupported = true;

/// A fresh scratch folder of its own.
Future<String> plTempDir() async => (await Directory.systemTemp.createTemp('dracondex-portlink')).path;

/// Where the bases live (`<app support>/portlink/`), made on first use.
Future<String> plBaseDir() async {
  final d = Directory('${(await getApplicationSupportDirectory()).path}/portlink');
  await d.create(recursive: true);
  return d.path;
}

/// This app's asset folder for a Nexus — where asset_files_io.dart stores a picked file.
Future<String> plAssetDir(int nexusId) async => '${(await getApplicationDocumentsDirectory()).path}/assets/$nexusId';

Future<void> plCopy(String from, String to) async {
  await File(to).parent.create(recursive: true);
  await File(from).copy(to);
}

Future<bool> plExists(String path) => File(path).exists();

Future<String> plRead(String path) => File(path).readAsString();

/// Never throws: a leftover scratch file is not worth failing a sync for.
Future<void> plDelete(String path) async {
  try {
    final t = FileSystemEntity.typeSync(path);
    if (t == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (t != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  } catch (_) {}
}

Future<void> plEnsureParent(String path) => File(path).parent.create(recursive: true);

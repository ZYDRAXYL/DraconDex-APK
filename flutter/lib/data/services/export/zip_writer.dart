import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One file in a zip. [data] is a String (written as UTF-8) or bytes.
/// [store] keeps it uncompressed — an EPUB's `mimetype` must be (OCF §4.3).
class ZipEntry {
  final String name;
  final List<int> bytes;
  final bool store;
  ZipEntry(this.name, Object data, {this.store = false}) : bytes = data is String ? utf8.encode(data) : data as List<int>;
}

/// The zip every export here writes (the port of EXE db/zip.js), in the
/// order given — the order is what puts `mimetype` first in an EPUB.
Uint8List writeZip(List<ZipEntry> entries) {
  final a = Archive();
  for (final e in entries) {
    final f = ArchiveFile(e.name, e.bytes.length, e.bytes);
    f.compress = !e.store;
    a.addFile(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

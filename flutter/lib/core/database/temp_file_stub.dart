import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) =>
    throw UnsupportedError('readFileBytes is not supported on this platform.');

Future<String> writeTempFile(String fileName, Uint8List bytes) =>
    throw UnsupportedError('writeTempFile is not supported on this platform.');

Future<void> deleteTempFile(String path) async {}

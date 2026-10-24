import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/data/services/ddx_transfer_service.dart';
import 'package:dracondex/data/services/snapshot_codec.dart';

/// Procress 19 part 4: the snapshot codec runs on a background isolate here
/// (dart:io), and has to give the bytes the in-place code gave.
void main() {
  final value = {
    'format': 'dracondex-vault-snapshot',
    'modules': [for (var i = 0; i < 50; i++) {'id': i, 'name': 'M$i — ✓'}],
  };

  test('encode/decode round trip, plain and gzipped', () async {
    final plain = await SnapshotCodec.encode(value);
    expect(plain, utf8.encode(jsonEncode(value)));
    expect(await SnapshotCodec.decode(plain), value);

    final sized = await SnapshotCodec.encodeSized(value, gzipped: true);
    expect(sized.plainBytes, plain.length);
    // Bytes 4-7 of a gzip header are MTIME, the second it was written: two
    // calls either side of a second boundary differ there and nowhere else.
    Uint8List noMtime(List<int> b) => Uint8List.fromList(b)..fillRange(4, 8, 0);
    expect(noMtime(sized.bytes), noMtime(DdxTransferService.gzip(plain)), reason: 'the bytes the transfer always sent');
    expect(await SnapshotCodec.decode(sized.bytes, gzipped: true), value);
    expect(await SnapshotCodec.decodeText(jsonEncode(value)), value);
  });

  test('not JSON is null, not a throw', () async {
    expect(await SnapshotCodec.decode(Uint8List.fromList(utf8.encode('{nope'))), isNull);
    expect(await SnapshotCodec.decodeText('nope'), isNull);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/platform/background.dart';

/// A snapshot's bytes <-> its decoded JSON, off the UI isolate on a native
/// build (Procress 19 part 4, core/platform/background.dart). The stress
/// vault's 637 KB snapshot took ~50 ms to decode — three frames — on the
/// isolate that draws them; a .ddata, a trash restore and a DDX Transfer
/// all decode one. On the web this runs in place, as it always did.
///
/// Each closure below captures only its own arguments: Isolate.run copies
/// whatever a closure holds, so one that reached a Database would fail.
class SnapshotCodec {
  /// UTF-8 JSON (gunzipped first when [gzipped]); null when it is not JSON.
  static Future<Object?> decode(Uint8List bytes, {bool gzipped = false, bool allowMalformed = false}) =>
      inBackground(() => _decode(bytes, gzipped, allowMalformed));

  /// JSON text already in memory (a trash row's payload).
  static Future<Object?> decodeText(String text) => inBackground(() => _decodeText(text));

  /// [value] as UTF-8 JSON, gzipped when [gzipped].
  static Future<Uint8List> encode(Object? value, {bool gzipped = false}) => inBackground(() => _encode(value, gzipped));

  /// [encode], and how long the JSON was before gzip (a transfer's manifest
  /// says both).
  static Future<({int plainBytes, Uint8List bytes})> encodeSized(Object? value, {bool gzipped = false}) =>
      inBackground(() => _encodeSized(value, gzipped));

  static Object? _decode(Uint8List bytes, bool gzipped, bool allowMalformed) {
    try {
      final raw = gzipped ? GZipDecoder().decodeBytes(bytes) : bytes;
      return jsonDecode(utf8.decode(raw, allowMalformed: allowMalformed));
    } on FormatException {
      return null;
    }
  }

  static Object? _decodeText(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static Uint8List _encode(Object? value, bool gzipped) => _encodeSized(value, gzipped).bytes;

  static ({int plainBytes, Uint8List bytes}) _encodeSized(Object? value, bool gzipped) {
    final plain = utf8.encode(jsonEncode(value));
    return (
      plainBytes: plain.length,
      bytes: gzipped ? Uint8List.fromList(GZipEncoder().encode(plain) ?? const <int>[]) : plain,
    );
  }
}

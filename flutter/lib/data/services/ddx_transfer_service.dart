import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// DDX Transfer — hand a whole Nexus to another device through the service in
/// ZYDRAXYL/DraconDex-TRX.
///
/// This is the Dart third of a THREE-WAY WIRE CONTRACT. The other two are
/// `public/assets/js/ddx-crypto.js` in DraconDex-TRX (the source of truth) and
/// `electron/src/db/transfer-crypto.js` in DraconDex-EXE. A mismatch between
/// any two of them does not throw — it lands a vault that imports as nonsense,
/// on someone else's machine, hours later — so every parameter is written out
/// here rather than left to a library default:
///
///   key        32 random bytes, made by the sender, NEVER uploaded
///   payload    gzip(snapshot JSON) -> split -> AES-256-GCM per chunk
///   chunk      [12-byte IV][ciphertext || 16-byte GCM tag]
///   manifest   AES-256-GCM over JSON, carried as { iv, ct } (base64)
///   pinWrap    AES-256-GCM over the key, under
///              PBKDF2-SHA256(code + ":" + pin, salt, 600000) -> 32 bytes
///
/// `package:cryptography` returns the GCM tag as a separate `SecretBox.mac`;
/// WebCrypto and node:crypto both APPEND it to the ciphertext. Reassembling it
/// in that order is what makes all three interoperate, and getting it wrong is
/// silent in one direction.
class DdxTransferService {
  DdxTransferService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/+$'), '');

  static const String defaultBaseUrl = 'https://dracondex-transfer.netlify.app';

  static const int keyBytes = 32;
  static const int ivBytes = 12;
  static const int tagBytes = 16;
  static const int pbkdf2Iters = 600000;

  final http.Client _client;
  final String baseUrl;

  static final _aes = AesGcm.with256bits(nonceLength: ivBytes);

  // -------------------------------------------------------------------
  // Crypto
  // -------------------------------------------------------------------

  static Uint8List _randomBytes(int n) {
    final rnd = SecretKeyData.random(length: n);
    return Uint8List.fromList(rnd.bytes);
  }

  static Uint8List newKey() => _randomBytes(keyBytes);

  static Future<Uint8List> _seal(List<int> key, List<int> plaintext, List<int> iv) async {
    final box = await _aes.encrypt(plaintext, secretKey: SecretKey(key), nonce: iv);
    // iv || ciphertext || tag — the tag goes at the END, appended to the
    // ciphertext, because that is where the other two implementations put it.
    return Uint8List.fromList(<int>[...iv, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> _open(List<int> key, List<int> framed) async {
    if (framed.length < ivBytes + tagBytes) {
      throw const DdxTransferException('bad_payload');
    }
    final iv = framed.sublist(0, ivBytes);
    final body = framed.sublist(ivBytes);
    final box = SecretBox(
      body.sublist(0, body.length - tagBytes),
      nonce: iv,
      mac: Mac(body.sublist(body.length - tagBytes)),
    );
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: SecretKey(key)));
  }

  /// Frames one chunk as [IV][ciphertext||tag] so a chunk carries its own nonce.
  static Future<Uint8List> sealChunk(List<int> key, List<int> plaintext) =>
      _seal(key, plaintext, _randomBytes(ivBytes));

  /// `<`, not `<=`: an empty payload seals to exactly IV + tag and is a
  /// perfectly valid authenticated chunk. Rejecting it would make an empty
  /// vault the one thing that cannot be sent.
  static Future<Uint8List> openChunk(List<int> key, List<int> framed) => _open(key, framed);

  static Future<Map<String, String>> sealJson(List<int> key, Object? value) async {
    final iv = _randomBytes(ivBytes);
    final framed = await _seal(key, utf8.encode(jsonEncode(value)), iv);
    return <String, String>{
      'iv': base64.encode(iv),
      'ct': base64.encode(framed.sublist(ivBytes)),
    };
  }

  static Future<Map<String, Object?>> openJson(List<int> key, Map sealed) async {
    final iv = base64.decode('${sealed['iv']}');
    final ct = base64.decode('${sealed['ct']}');
    final plain = await _open(key, <int>[...iv, ...ct]);
    return (jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>();
  }

  /// The sender seals under the code as the SERVICE issued it (`ABCDEFGH`) and
  /// the receiver types it as the screen shows it (`abcd-efgh`). Both have to
  /// derive from the same string or the typed-code path fails every time while
  /// looking exactly like a wrong PIN — including the Crockford I/L -> 1 and
  /// O -> 0 substitutions, which are the whole reason the alphabet skips them.
  static String canonicalCode(Object? raw) => '$raw'
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z]'), '')
      .replaceAll(RegExp(r'[IL]'), '1')
      .replaceAll('O', '0');

  static String canonicalPin(Object? raw) => '$raw'.replaceAll(RegExp(r'[^0-9]'), '');

  static Future<Uint8List> _deriveWrapKey(String code, String pin, List<int> salt, int iters) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iters,
      bits: keyBytes * 8,
    );
    final derived = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode('${canonicalCode(code)}:${canonicalPin(pin)}')),
      nonce: salt,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// Seals the transfer key under the PIN — the typed-code path only. Omitting
  /// this is what makes a transfer end-to-end: with no wrapped key stored, the
  /// QR/link fragment holds the only copy of it in existence.
  static Future<Map<String, Object?>> wrapKeyWithPin(
      List<int> key, String code, String pin) async {
    final salt = _randomBytes(16);
    final iv = _randomBytes(ivBytes);
    final framed = await _seal(await _deriveWrapKey(code, pin, salt, pbkdf2Iters), key, iv);
    return <String, Object?>{
      'iv': base64.encode(iv),
      'ct': base64.encode(framed.sublist(ivBytes)),
      'salt': base64.encode(salt),
      'iters': pbkdf2Iters,
    };
  }

  static Future<Uint8List> unwrapKeyWithPin(Map pinWrap, String code, String pin) async {
    final iters = pinWrap['iters'] is int ? pinWrap['iters'] as int : pbkdf2Iters;
    final wrapKey = await _deriveWrapKey(code, pin, base64.decode('${pinWrap['salt']}'), iters);
    final iv = base64.decode('${pinWrap['iv']}');
    final ct = base64.decode('${pinWrap['ct']}');
    return _open(wrapKey, <int>[...iv, ...ct]);
  }

  /// `package:archive` rather than `dart:io`'s GZipCodec: the web build has no
  /// `dart:io` at all, and this same service runs there.
  static Uint8List gzip(List<int> bytes) =>
      Uint8List.fromList(GZipEncoder().encode(bytes) ?? const <int>[]);

  static Uint8List gunzip(List<int> bytes) =>
      Uint8List.fromList(GZipDecoder().decodeBytes(bytes));

  /// The service rejects chunkCount < 1, so "nothing to send" has to mean one
  /// chunk carrying nothing, not no chunks at all.
  static List<Uint8List> splitChunks(Uint8List bytes, int maxPlainBytes) {
    if (bytes.isEmpty) return <Uint8List>[Uint8List(0)];
    final out = <Uint8List>[];
    for (var at = 0; at < bytes.length; at += maxPlainBytes) {
      final end = at + maxPlainBytes < bytes.length ? at + maxPlainBytes : bytes.length;
      out.add(Uint8List.sublistView(bytes, at, end));
    }
    return out;
  }

  // -------------------------------------------------------------------
  // Transport
  // -------------------------------------------------------------------

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, Object?> _decode(http.Response res) {
    Map<String, Object?> body;
    try {
      body = (jsonDecode(res.body) as Map).cast<String, Object?>();
    } catch (_) {
      throw const DdxTransferException('server_error');
    }
    if (body['ok'] == false) {
      throw DdxTransferException(
        body['code'] is String ? body['code'] as String : 'server_error',
        retryAfterMs: body['retryAfterMs'] is int ? body['retryAfterMs'] as int : null,
      );
    }
    return body;
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on DdxTransferException {
      rethrow;
    } catch (_) {
      // A dead network and a refusing service want different messages, so they
      // never collapse into one generic failure.
      throw const DdxTransferException('network');
    }
  }

  // -------------------------------------------------------------------
  // Send
  // -------------------------------------------------------------------

  /// Seals a serialized snapshot and uploads it. `allowTypedCode: false`
  /// withholds `pinWrap`, which is what makes the transfer end-to-end.
  Future<TransferSendResult> send({
    required Map<String, Object?> snapshot,
    required String name,
    bool allowTypedCode = true,
    void Function(double progress)? onProgress,
  }) async {
    final key = newKey();
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    final body = gzip(plain);

    final created = _decode(await _send(() => _client.post(
          _uri('/api/create'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'sizeBytes': body.length}),
        )));

    final transferId = '${created['transferId']}';
    final uploadToken = '${created['uploadToken']}';
    final maxChunkBytes = created['maxChunkBytes'] as int;
    final maxChunks = created['maxChunks'] as int;

    // The framing costs an IV and a tag per chunk, so the plaintext slice has
    // to be smaller than the service's cap by exactly that much — otherwise
    // the LAST chunk of a large vault is the one thing that gets rejected.
    final slices = splitChunks(body, maxChunkBytes - ivBytes - tagBytes);
    if (slices.length > maxChunks) throw const DdxTransferException('too_large');

    for (var i = 0; i < slices.length; i++) {
      final framed = await sealChunk(key, slices[i]);
      _decode(await _send(() => _client.put(
            _uri('/api/chunk/$transferId/$i'),
            headers: {
              'authorization': 'Bearer $uploadToken',
              'content-type': 'application/octet-stream',
            },
            body: framed,
          )));
      onProgress?.call((i + 1) / slices.length);
    }

    final code = '${created['code']}';
    final pin = '${created['pin']}';

    final manifest = <String, Object?>{
      'v': 1,
      'name': name,
      'sizeBytes': plain.length,
      'compression': 'gzip',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'source': 'apk',
    };

    _decode(await _send(() => _client.post(
          _uri('/api/commit'),
          headers: {
            'authorization': 'Bearer $uploadToken',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'transferId': transferId,
            'chunkCount': slices.length,
            'sizeBytes': body.length,
            'manifestEnc': await sealJson(key, manifest),
            'pinWrap': allowTypedCode ? await wrapKeyWithPin(key, code, pin) : null,
          }),
        )));

    return TransferSendResult(
      transferId: transferId,
      uploadToken: uploadToken,
      code: code,
      codeDisplay: '${created['codeDisplay']}',
      pin: pin,
      pinDisplay: '${created['pinDisplay']}',
      allowTypedCode: allowTypedCode,
      expiresAt: created['expiresAt'] as int,
      // The secrets go after the '#', which browsers never put on the wire and
      // servers therefore never see.
      link: '$baseUrl/t/$code#k=${_base64Url(key)}&p=$pin',
    );
  }

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  Future<TransferStatus> status(String transferId, String uploadToken) async {
    final body = _decode(await _send(() => _client.get(
          _uri('/api/status/$transferId'),
          headers: {'authorization': 'Bearer $uploadToken'},
        )));
    return TransferStatus(
      status: '${body['status']}',
      claimed: body['claimed'] == true,
    );
  }

  Future<void> cancel(String transferId, String uploadToken) async {
    await _send(() => _client.delete(
          _uri('/api/cancel/$transferId'),
          headers: {'authorization': 'Bearer $uploadToken'},
        ));
  }

  // -------------------------------------------------------------------
  // Receive
  // -------------------------------------------------------------------

  /// Step one: prove the code and PIN, open the manifest locally, and hand
  /// back only what a person needs to decide with. No payload is fetched here
  /// — that is the point of the two-step.
  ///
  /// [linkKey] is the raw key from a scanned/pasted link fragment. Without it
  /// the key has to come from the service's `pinWrap`, and a sender who chose
  /// QR-only did not store one.
  Future<TransferVerifyResult> verify({
    required String code,
    required String pin,
    List<int>? linkKey,
  }) async {
    final body = _decode(await _send(() => _client.post(
          _uri('/api/verify'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'code': code, 'pin': pin}),
        )));

    // Deliberately a separate non-nullable local rather than reassigning
    // `linkKey`: flow analysis across an await inside a try/catch is exactly
    // the shape that trips the analyzer, and the fix should not be a `!`.
    final List<int> key;
    if (linkKey != null) {
      key = linkKey;
    } else {
      final pinWrap = body['pinWrap'];
      // No key from a link and nothing wrapped on the service means the sender
      // chose QR-only. Typing the code is simply not a door into this one.
      if (pinWrap is! Map) throw const DdxTransferException('qr_only');
      try {
        key = await unwrapKeyWithPin(pinWrap, code, pin);
      } catch (_) {
        throw const DdxTransferException('bad_key');
      }
    }

    Map<String, Object?> manifest;
    try {
      manifest = await openJson(key, body['manifestEnc'] as Map);
    } catch (_) {
      // The service already accepted the PIN, so a manifest that will not open
      // means the KEY is wrong — a mangled fragment, not a mistyped PIN.
      throw const DdxTransferException('bad_key');
    }

    return TransferVerifyResult(
      transferId: '${body['transferId']}',
      receiptToken: '${body['receiptToken']}',
      chunkCount: body['chunkCount'] as int,
      key: key,
      name: '${manifest['name']}',
      sizeBytes: manifest['sizeBytes'] is int ? manifest['sizeBytes'] as int : 0,
      createdAt: manifest['createdAt'] is int ? manifest['createdAt'] as int : 0,
      source: manifest['source'] is String ? manifest['source'] as String : null,
      compression: '${manifest['compression']}',
    );
  }

  /// Step two: pull every chunk, decrypt, decompress, and only then tell the
  /// service to forget it. Purging any earlier would throw the vault away on a
  /// failed decode with no way to ask for it again.
  Future<Map<String, Object?>> receive(
    TransferVerifyResult session, {
    void Function(double progress)? onProgress,
  }) async {
    final parts = <int>[];
    for (var i = 0; i < session.chunkCount; i++) {
      final res = await _send(() => _client.get(
            _uri('/api/chunk/${session.transferId}/$i'),
            headers: {'authorization': 'Bearer ${session.receiptToken}'},
          ));
      if (res.statusCode >= 400) _decode(res);
      parts.addAll(await openChunk(session.key, res.bodyBytes));
      onProgress?.call((i + 1) / session.chunkCount);
    }

    Map<String, Object?> payload;
    try {
      final raw = session.compression == 'gzip' ? gunzip(parts) : Uint8List.fromList(parts);
      payload = (jsonDecode(utf8.decode(raw)) as Map).cast<String, Object?>();
    } catch (_) {
      throw const DdxTransferException('bad_payload');
    }

    try {
      await _send(() => _client.post(
            _uri('/api/complete'),
            headers: {
              'authorization': 'Bearer ${session.receiptToken}',
              'content-type': 'application/json',
            },
            body: jsonEncode({'transferId': session.transferId}),
          ));
    } catch (_) {
      // The sweeper is the backstop and the user already has their data.
    }

    return payload;
  }

  /// Pulls the code and the secrets out of a transfer link. Accepts the whole
  /// URL as pasted — the fragment is where the key lives, so a link copied out
  /// of a message carries everything the receiver needs.
  static TransferLink? parseLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final code = canonicalCode(segments.last);
    if (code.length != 8) return null;

    final frag = Uri.splitQueryString(uri.fragment);
    List<int>? key;
    final k = frag['k'];
    if (k != null && k.isNotEmpty) {
      try {
        key = base64Url.decode(k.padRight((k.length + 3) ~/ 4 * 4, '='));
      } catch (_) {
        key = null;
      }
      if (key != null && key.length != keyBytes) key = null;
    }
    return TransferLink(code: code, pin: canonicalPin(frag['p'] ?? ''), key: key);
  }
}

class DdxTransferException implements Exception {
  const DdxTransferException(this.code, {this.retryAfterMs});

  /// One of the service's error codes. Callers map it to a localized string —
  /// a raw code never reaches the user.
  final String code;
  final int? retryAfterMs;

  @override
  String toString() => 'DdxTransferException($code)';
}

class TransferSendResult {
  const TransferSendResult({
    required this.transferId,
    required this.uploadToken,
    required this.code,
    required this.codeDisplay,
    required this.pin,
    required this.pinDisplay,
    required this.allowTypedCode,
    required this.expiresAt,
    required this.link,
  });

  final String transferId;
  final String uploadToken;
  final String code;
  final String codeDisplay;
  final String pin;
  final String pinDisplay;
  final bool allowTypedCode;
  final int expiresAt;
  final String link;
}

class TransferStatus {
  const TransferStatus({required this.status, required this.claimed});

  final String status;
  final bool claimed;
}

class TransferVerifyResult {
  const TransferVerifyResult({
    required this.transferId,
    required this.receiptToken,
    required this.chunkCount,
    required this.key,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.source,
    required this.compression,
  });

  final String transferId;
  final String receiptToken;
  final int chunkCount;

  /// Stays in this object and never reaches a widget, a log, or storage.
  final List<int> key;

  final String name;
  final int sizeBytes;
  final int createdAt;
  final String? source;
  final String compression;
}

class TransferLink {
  const TransferLink({required this.code, required this.pin, required this.key});

  final String code;
  final String pin;
  final List<int>? key;
}

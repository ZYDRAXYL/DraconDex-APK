import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/data/services/ddx_transfer_service.dart';

/// The DDX Transfer wire format is implemented THREE times: here in Dart,
/// in `public/assets/js/ddx-crypto.js` (DraconDex-TRX, the source of truth),
/// and in `electron/src/db/transfer-crypto.js` (DraconDex-EXE).
///
/// A disagreement between any two of them does not throw. It hands someone a
/// vault that imports as nonsense, on another device, hours later — which is
/// exactly the kind of bug that survives every test that only ever exercises
/// one implementation.
///
/// So the vectors below were produced by the NODE implementation and are
/// pasted in verbatim. If this file goes green, Dart can open what Electron
/// seals; the reverse direction is covered by the round-trips further down,
/// since both use the same code path in opposite order.
void main() {
  final key = _hex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');

  group('golden vectors from the Node implementation', () {
    test('opens a chunk Electron sealed', () async {
      final framed = base64.decode('NX3qPODu9NQeCD3WhPQP7dgmCQaSca+PmoMf2C2mzUv4pX9NT4UVt3RY6czU7zmh1nMCb/fQxRi1sQwUj2R2M+PjKjCu');
      final plain = await DdxTransferService.openChunk(key, framed);
      expect(utf8.decode(plain), 'DraconDex vault chunk — ทดสอบ');
    });

    test('opens a manifest Electron sealed', () async {
      final manifest = await DdxTransferService.openJson(key, <String, Object?>{
        'iv': 'aGoZORBHh5nrw+cr',
        'ct': 'qxCirDQUQxDWo8AJtUbDKiOvLLDOvjn2cgislmSLx7myGkRTo+7jsLRwNovDdA3Ut6zHETswtCkoxj8PTBq/6gSgebA86nXULkrDPRAPVBX7G84EEjra4VbwPa6dNefRpUVsAjHYvGTV7kTepCLV14z5IrckuAmPZ2qBCU8q1pbZerjvEdqxxwzd0w==',
      });
      expect(manifest['name'], 'โลกของฉัน');
      expect(manifest['sizeBytes'], 2411);
      expect(manifest['compression'], 'gzip');
      expect(manifest['source'], 'exe');
    });

    test('unwraps a key Electron sealed under the PIN', () async {
      final wrap = <String, Object?>{
        'iv': 'iOEz9sL5plv1/9nE',
        'ct': 'LX/S3oMhhl2+fuuraLWMmNFjkHi2w9SyWKILDFbA2ls5vdkqqCPADlNfg3/qEr94',
        'salt': 'mzXkgomvSgcKUmJ+xXCxSQ==',
        'iters': 600000,
      };
      final unwrapped =
          await DdxTransferService.unwrapKeyWithPin(wrap, 'ABCD1234', '482719');
      expect(unwrapped, key);
    });

    test('unwraps it from the code and PIN as a person types them', () async {
      // The sender sealed under what the service issued (ABCD1234); the
      // receiver types what the screen showed (abcd-1234 / 482-719). Both
      // have to canonicalise to the same string or the typed-code path fails
      // every time while looking exactly like a wrong PIN.
      final wrap = <String, Object?>{
        'iv': 'iOEz9sL5plv1/9nE',
        'ct': 'LX/S3oMhhl2+fuuraLWMmNFjkHi2w9SyWKILDFbA2ls5vdkqqCPADlNfg3/qEr94',
        'salt': 'mzXkgomvSgcKUmJ+xXCxSQ==',
        'iters': 600000,
      };
      for (final typed in <List<String>>[
        <String>['abcd-1234', '482-719'],
        <String>['ABCD 1234', '482 719'],
        <String>['  abcd1234  ', '482719'],
      ]) {
        expect(
          await DdxTransferService.unwrapKeyWithPin(wrap, typed[0], typed[1]),
          key,
          reason: 'typed as "${typed[0]}" / "${typed[1]}"',
        );
      }
    });

    test('the wrong PIN does not unwrap', () async {
      final wrap = <String, Object?>{
        'iv': 'iOEz9sL5plv1/9nE',
        'ct': 'LX/S3oMhhl2+fuuraLWMmNFjkHi2w9SyWKILDFbA2ls5vdkqqCPADlNfg3/qEr94',
        'salt': 'mzXkgomvSgcKUmJ+xXCxSQ==',
        'iters': 600000,
      };
      expect(
        () => DdxTransferService.unwrapKeyWithPin(wrap, 'ABCD1234', '000000'),
        throwsA(anything),
      );
    });

    test('opens a gzipped snapshot Electron sealed, end to end', () async {
      final framed = base64.decode('lUhS3TDamYoP/VKX/PiiEvrgYQf9G3HjniJeGITzq2EJbdph5JyiCmA7Spdc4nRtfMUAGVi5AtDDZVi70YBDf/b4dBPJcf2FX6popBmSa66Y0AAIrbiFFyb7NtH3Mt8BLJSlGOtzBlyrMMD6GNaabVsU7tqYd8+DmQAwzpj+J9bbAg==');
      final gz = await DdxTransferService.openChunk(key, framed);
      final json = jsonDecode(utf8.decode(DdxTransferService.gunzip(gz))) as Map;
      expect(json['format'], 'dracondex-vault-snapshot');
      expect(json['version'], 1);
      expect((json['nexus'] as Map)['name'], 'My World');
    });

    test('opens an EMPTY chunk Electron sealed', () async {
      // An empty payload seals to exactly IV + tag. A `<=` length guard made
      // an empty vault the one thing that could not be sent.
      final framed = base64.decode('cDBUYKEOKmdNxuxAQNbCCq/nclLGT7h2ce10zg==');
      expect(await DdxTransferService.openChunk(key, framed), isEmpty);
    });
  });

  group('the wire parameters', () {
    test('are the ones all three implementations agree on', () {
      expect(DdxTransferService.keyBytes, 32);
      expect(DdxTransferService.ivBytes, 12);
      expect(DdxTransferService.tagBytes, 16);
      expect(DdxTransferService.pbkdf2Iters, 600000);
    });
  });

  group('round trips', () {
    test('a chunk seals and opens', () async {
      final k = DdxTransferService.newKey();
      final plain = utf8.encode('a vault');
      final framed = await DdxTransferService.sealChunk(k, plain);
      // iv || ciphertext || tag, with the tag APPENDED — where WebCrypto and
      // node:crypto both put it.
      expect(framed.length,
          DdxTransferService.ivBytes + plain.length + DdxTransferService.tagBytes);
      expect(await DdxTransferService.openChunk(k, framed), plain);
    });

    test('a tampered chunk fails the tag rather than decrypting to garbage', () async {
      final k = DdxTransferService.newKey();
      final framed = await DdxTransferService.sealChunk(k, utf8.encode('a vault'));
      framed[framed.length - 1] ^= 1;
      expect(() => DdxTransferService.openChunk(k, framed), throwsA(anything));
    });

    test('the wrong key fails the same way', () async {
      final framed =
          await DdxTransferService.sealChunk(DdxTransferService.newKey(), utf8.encode('a vault'));
      expect(
        () => DdxTransferService.openChunk(DdxTransferService.newKey(), framed),
        throwsA(anything),
      );
    });

    test('gzip round-trips and actually compresses', () {
      final body = utf8.encode(jsonEncode(<String, Object?>{
        'modules': List<Map<String, Object?>>.generate(
            400, (i) => <String, Object?>{'id': i, 'name': 'Module $i', 'kind': 'classifier'}),
      }));
      final gz = DdxTransferService.gzip(body);
      expect(gz.length, lessThan(body.length ~/ 4));
      expect(DdxTransferService.gunzip(gz), body);
    });

    test('splitChunks never returns zero chunks', () {
      // The service rejects chunkCount < 1, so "nothing to send" has to mean
      // one chunk carrying nothing.
      expect(DdxTransferService.splitChunks(Uint8List.fromList(<int>[]), 1024).length, 1);
      expect(DdxTransferService.splitChunks(Uint8List.fromList(List<int>.filled(2500, 7)), 1000).length, 3);
    });
  });

  group('link parsing', () {
    test('pulls the code, PIN and key out of a transfer link', () {
      final k = DdxTransferService.newKey();
      final b64 = base64Url.encode(k).replaceAll('=', '');
      final parsed = DdxTransferService.parseLink(
          'https://transfer.example/t/ABCD1234#k=$b64&p=482719');
      expect(parsed, isNotNull);
      expect(parsed!.code, 'ABCD1234');
      expect(parsed.pin, '482719');
      expect(parsed.key, k);
    });

    test('applies the Crockford substitutions the alphabet exists for', () {
      // I, L, O and U are excluded from the code alphabet precisely because
      // they get misread, so reading a 1 back as an I still has to resolve.
      expect(DdxTransferService.canonicalCode('IL0O-1234'), '11001234');
      expect(DdxTransferService.canonicalPin('482-719'), '482719');
    });

    test('returns null for something that is not a transfer link', () {
      expect(DdxTransferService.parseLink('not a url at all here'), isNull);
      expect(DdxTransferService.parseLink('https://example.com/'), isNull);
    });

    test('a link with no fragment still yields the code', () {
      final parsed = DdxTransferService.parseLink('https://transfer.example/t/ABCD-1234');
      expect(parsed, isNotNull);
      expect(parsed!.code, 'ABCD1234');
      expect(parsed.key, isNull);
    });
  });
}

List<int> _hex(String s) => <int>[
      for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
    ];

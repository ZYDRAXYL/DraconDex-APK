import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/data/services/update_service.dart';

/// Procress 29 part 7: the checksums file is trusted only when the project's
/// key signed exactly it — the key in the desktop's SPKI/base64 form
/// (DraconDex-EXE .github/scripts/sign-checksums.mjs --keygen).
void main() {
  test('the signing key says yes; a changed byte, another key, no or bad signature say no', () async {
    final algo = Ed25519();
    Future<String> spkiOf(SimpleKeyPair kp) async {
      final raw = (await kp.extractPublicKey()).bytes;
      return base64Encode([...const [0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00], ...raw]);
    }
    final kp = await algo.newKeyPair();
    final pub = await spkiOf(kp);
    const text = 'abc123  DraconDex-flutter-3.6.0.apk\n';
    final sig = base64Encode((await algo.sign(utf8.encode(text), keyPair: kp)).bytes);
    expect(await UpdateService.checksumsSigned(text, sig, pub), isTrue);
    expect(await UpdateService.checksumsSigned(text.replaceFirst('abc', 'abd'), sig, pub), isFalse);
    expect(await UpdateService.checksumsSigned(text, sig, await spkiOf(await algo.newKeyPair())), isFalse);
    expect(await UpdateService.checksumsSigned(text, null, pub), isFalse);
    expect(await UpdateService.checksumsSigned(text, 'not base64 !!', pub), isFalse);
    expect(await UpdateService.checksumsSigned(text, null, ''), isTrue, reason: 'no key set = not checked');
  });

  test('a key and signature made by the desktop script (node crypto) verify here', () async {
    // node: crypto.generateKeyPairSync('ed25519'); publicKey.export({format:'der',type:'spki'}); crypto.sign(null, text, privateKey)
    const pub = 'MCowBQYDK2VwAyEASQGuCTgSjId0UbtIC+pZJIlHxuNZADKj6ElS0QPko4Y=';
    const sig = 'UcK3j9vQyeigFo1+9LtA06amgu3rkhY3C5ZqaOKaHi4srvY89NV+D5WMBtu8rDUN1+qzbX4iMFu3kCMDzQiMCw==';
    const text = 'abc123  DraconDex-flutter-3.6.0.apk\n';
    expect(await UpdateService.checksumsSigned(text, sig, pub), isTrue);
    expect(await UpdateService.checksumsSigned('$text ', sig, pub), isFalse);
  });
}

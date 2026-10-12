import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dracondex/data/services/ddx_transfer_service.dart';

/// The send key (DraconDex-TRX `_lib/sendkey.mts`): every `/api/create`
/// carries what the user typed, the service's refusals come back as their own
/// codes, and `locked` from create is renamed so the screen blames the key
/// rather than a PIN.
void main() {
  http.Response refuse(String code, int status) => http.Response(
        jsonEncode({'ok': false, 'code': code}),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<String> sendAndCatch(MockClient client, {String sendKey = ''}) async {
    final service = DdxTransferService(client: client, baseUrl: 'https://transfer.example');
    try {
      await service.send(snapshot: const {'v': 2}, name: 'World', sendKey: sendKey);
      return 'ok';
    } on DdxTransferException catch (e) {
      return e.code;
    }
  }

  test('create carries the send key the user typed', () async {
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      if (req.url.path == '/api/create') sent = jsonDecode(req.body) as Map<String, dynamic>;
      return refuse('bad_send_key', 403);
    });
    final code = await sendAndCatch(client, sendKey: 'ABCD-EFGH-JKMN');
    expect(sent?['sendKey'], 'ABCD-EFGH-JKMN');
    expect(sent?['sizeBytes'], isA<int>());
    expect(code, 'bad_send_key');
  });

  test('a missing key surfaces as send_key_required', () async {
    final code = await sendAndCatch(MockClient((_) async => refuse('send_key_required', 401)));
    expect(code, 'send_key_required');
  });

  test('locked from create means too many wrong keys, not PINs', () async {
    final code = await sendAndCatch(MockClient((_) async => refuse('locked', 429)));
    expect(code, 'send_key_locked');
  });
}

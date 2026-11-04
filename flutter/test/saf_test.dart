// Port Link 9.1 — the Dart side of the SAF channel: what it sends to
// MainActivity/SafChannel.kt, what it makes of the answers, that it never lets
// a path climb out of the picked folder, and that off Android it answers
// "nothing there" instead of throwing (the same tree builds the PWA).
import 'package:dracondex/core/platform/saf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  const tree = 'content://com.android.externalstorage.documents/tree/1A2B-3C4D%3ADDX';

  setUp(() {
    calls.clear();
    Saf.supportedOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(Saf.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'pickTree':
          return tree;
        case 'trees':
          return [tree];
        case 'available':
          return true;
        case 'stat':
          return {'size': 4096, 'mtime': 1762246800000, 'dir': false};
        case 'list':
          return [
            {'name': 'app.ddx', 'dir': false, 'size': 8192, 'mtime': 1},
            {'name': 'vaults', 'dir': true, 'size': 0, 'mtime': 2},
          ];
        default:
          return true;
      }
    });
  });
  tearDown(() => Saf.supportedOverride = null);

  test('calls carry the tree and a clean relative path', () async {
    expect(await Saf.pickTree(), tree);
    expect(await Saf.trees(), [tree]);
    expect(await Saf.available(tree), isTrue);
    expect(await Saf.copyIn(tree, '/novel-manager-data//app.ddx', '/cache/app.ddx'), isTrue);
    final c = calls.firstWhere((c) => c.method == 'copyIn');
    expect(c.arguments, {'tree': tree, 'path': 'novel-manager-data/app.ddx', 'dest': '/cache/app.ddx'});
    expect(await Saf.copyOut(tree, 'novel-manager-data/vaults/Atlas-2.ddx', '/cache/w.ddx'), isTrue);
    expect(calls.last.arguments, {'tree': tree, 'path': 'novel-manager-data/vaults/Atlas-2.ddx', 'src': '/cache/w.ddx'});
  });

  test('answers become typed values; sig matches EXE size:mtime', () async {
    final s = await Saf.stat(tree, 'novel-manager-data/app.ddx');
    expect([s!.name, s.size, s.mtime, s.dir], ['app.ddx', 4096, 1762246800000, false]);
    expect(Saf.sig(s), '4096:1762246800000');
    expect(Saf.sig(null), isNull);
    final l = await Saf.list(tree, 'novel-manager-data');
    expect(l!.map((e) => [e.name, e.dir]).toList(), [['app.ddx', false], ['vaults', true]]);
  });

  test('a path that climbs out of the picked folder never reaches native code', () async {
    expect(() => Saf.copyIn(tree, '../other/app.ddx', '/cache/x'), throwsArgumentError);
    expect(() => Saf.delete(tree, 'novel-manager-data/../../x'), throwsArgumentError);
    expect(calls, isEmpty);
  });

  test('off Android: nothing there, no throw, no call', () async {
    Saf.supportedOverride = false;
    expect(await Saf.pickTree(), isNull);
    expect(await Saf.trees(), isEmpty);
    expect(await Saf.available(tree), isFalse);
    expect(await Saf.stat(tree, 'x'), isNull);
    expect(await Saf.copyOut(tree, 'x', '/y'), isFalse);
    expect(calls, isEmpty);
  });
}

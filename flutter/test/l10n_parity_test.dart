import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every ARB carries exactly app_en.arb's keys, with the same placeholders.
/// l10n codegen is off and the Dart files are handwritten, so the compiler
/// only proves each locale class implements every getter — not that the ARBs
/// the next generator run would read agree with them.
void main() {
  final dir = Directory('lib/core/i18n/l10n');
  Map<String, dynamic> read(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  Set<String> keys(Map<String, dynamic> m) => {for (final k in m.keys) if (!k.startsWith('@')) k};
  Set<String> holes(Object? v) => {for (final m in RegExp(r'\{(\w+)\}').allMatches('$v')) m[1]!};

  final en = read(File('${dir.path}/app_en.arb'));
  final arbs = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList();

  test('18 locales', () => expect(arbs.length, 18));

  for (final f in arbs) {
    final name = f.uri.pathSegments.last;
    test('$name has the en key set and placeholders', () {
      final m = read(f);
      expect(keys(m).difference(keys(en)), isEmpty, reason: 'extra keys');
      expect(keys(en).difference(keys(m)), isEmpty, reason: 'missing keys');
      for (final k in keys(en)) {
        expect(holes(m[k]), holes(en[k]), reason: k);
      }
    });
  }

  // The handwritten Dart class is what the app shows; the ARB is what the
  // next generator run (and every translator) reads. German once showed
  // twelve strings in English — "Title layout" in the page menu — because
  // its Dart getters held the English while its ARB had the translation.
  for (final f in arbs) {
    final code = RegExp(r'app_(\w+)\.arb').firstMatch(f.path)![1]!;
    test('app_localizations_$code.dart says what app_$code.arb says', () {
      final m = read(f);
      final dart = File('lib/core/i18n/app_localizations_$code.dart').readAsStringSync();
      final differ = <String>[];
      for (final g in RegExp(r"String get (\w+) => '((?:[^'\\]|\\.)*)';").allMatches(dart)) {
        final v = g[2]!.replaceAllMapped(RegExp(r'\\(.)'), (x) => x[1] == 'n' ? '\n' : x[1]!);
        if (m.containsKey(g[1]) && m[g[1]] != v) differ.add(g[1]!);
      }
      expect(differ, isEmpty);
    });
  }

  test('every locale is registered and has its Dart file', () {
    final main = File('lib/core/i18n/app_localizations.dart').readAsStringSync();
    for (final f in arbs) {
      final code = RegExp(r'app_(\w+)\.arb').firstMatch(f.path)![1]!;
      expect(File('lib/core/i18n/app_localizations_$code.dart').existsSync(), isTrue, reason: code);
      expect(main.contains("Locale('$code')"), isTrue, reason: code);
    }
  });
}

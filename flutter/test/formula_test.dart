import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/classifier/formula.dart';

/// The port of EXE core/formula.js — same grammar, same results.
void main() {
  double? v(String s, [Map<String, double> f = const {}]) => Formula.eval(s, (n) => f[n]).value;

  test('arithmetic, precedence, right-associative power, functions', () {
    expect(v('1 + 2 * 3'), 7);
    expect(v('(1 + 2) * 3'), 9);
    expect(v('2 ^ 3 ^ 2'), 512);
    expect(v('-2 ^ 2'), 4, reason: 'unary binds tighter, as in the JS');
    expect(v('7 % 4'), 3);
    expect(v('max(1, 5, 3) + min(4, 2)'), 7);
    expect(v('round(3.14159, 2)'), 3.14);
    expect(v('floor(2.7) + ceil(2.1) + abs(-1)'), 6);
    expect(v('{Strength} * 2 + {Level}', {'Strength': 10, 'Level': 3}), 23);
  });

  test('errors never throw', () {
    expect(Formula.eval('1 +', (_) => null).ok, isFalse);
    expect(Formula.eval('{Nope}', (_) => null).error, contains('no field'));
    expect(Formula.eval('eval(1)', (_) => null).error, contains('unknown function'));
    expect(Formula.eval('1; 2', (_) => null).ok, isFalse);
    expect(Formula.eval('', (_) => null).error, 'empty');
  });

  test('field values: empty stays empty, checkbox is 0/1, chains resolve, cycles fail', () {
    const hp = (id: 1, name: 'HP', type: 'number', options: null);
    const armed = (id: 2, name: 'Armed', type: 'checkbox', options: null);
    const dbl = (id: 3, name: 'Double', type: 'formula', options: '{"expr":"{HP} * 2 + {Armed}"}');
    const quad = (id: 4, name: 'Quad', type: 'formula', options: '{"expr":"{Double} * 2"}');
    const a = (id: 5, name: 'A', type: 'formula', options: '{"expr":"{B}"}');
    const b = (id: 6, name: 'B', type: 'formula', options: '{"expr":"{A}"}');
    final fields = [hp, armed, dbl, quad, a, b];
    expect(Formula.valueOf(dbl, fields, {1: '10', 2: '1'}).text, '21');
    expect(Formula.valueOf(quad, fields, {1: '10', 2: '0'}).text, '40');
    expect(Formula.valueOf(dbl, fields, {1: '', 2: '1'}).value, isNull);
    expect(Formula.valueOf(a, fields, {}).error, 'cycle');
    expect(const FormulaResult.ok(2.5).text, '2.5');
    expect(const FormulaResult.ok(1 / 3).text, '0.333');
  });
}

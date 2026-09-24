import 'dart:convert';
import 'dart:math' as math;

/// The result of a formula: a number, empty (an input was empty), or an
/// error for the UI.
class FormulaResult {
  final bool ok;
  final double? value;
  final String? error;
  final List<String> refs;
  const FormulaResult.ok(this.value, [this.refs = const []])
      : ok = true,
        error = null;
  const FormulaResult.fail(this.error, [this.refs = const []])
      : ok = false,
        value = null;

  /// The number as the desktop prints it: an integer bare, else rounded to
  /// three places; empty for no value.
  String get text {
    final v = value;
    if (v == null) return '';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return ((v * 1000).round() / 1000).toString();
  }
}

/// Formula fields (V5.md §11.6 "stat formulas") — the port of EXE
/// renderer/core/formula.js. Never an eval: a small recursive-descent parser
/// over a fixed grammar, so a formula can read numbers and nothing else.
///
///   expr    := term (('+' | '-') term)*
///   term    := factor (('*' | '/' | '%') factor)*
///   factor  := unary ('^' factor)?            right-associative power
///   unary   := '-' unary | primary
///   primary := number | {Field name} | fn '(' expr (',' expr)* ')' | '(' expr ')'
///   fn      := min | max | round | floor | ceil | abs
class Formula {
  static FormulaResult eval(String src, double? Function(String name) lookup) {
    final List<(String, Object?)> toks;
    try {
      toks = _tokenize(src);
    } on FormatException catch (e) {
      return FormulaResult.fail(e.message);
    }
    if (toks.isEmpty) return const FormulaResult.fail('empty');
    var p = 0;
    final refs = <String>[];
    (String, Object?)? peek() => p < toks.length ? toks[p] : null;
    void eat(String t) {
      if (peek()?.$1 != t) throw FormatException('expected $t');
      p++;
    }

    late double Function() expr;
    double primary() {
      final tk = peek();
      if (tk == null) throw const FormatException('unexpected end');
      switch (tk.$1) {
        case 'num':
          p++;
          return tk.$2 as double;
        case 'ref':
          p++;
          final name = tk.$2 as String;
          refs.add(name);
          final v = lookup(name);
          if (v == null) throw FormatException('no field "$name"');
          return v;
        case 'fn':
          p++;
          final name = tk.$2 as String;
          eat('(');
          final args = [expr()];
          while (peek()?.$1 == ',') {
            p++;
            args.add(expr());
          }
          eat(')');
          return _fn(name, args);
        case '(':
          p++;
          final v = expr();
          eat(')');
          return v;
      }
      throw FormatException('unexpected ${tk.$1}');
    }

    double unary() {
      if (peek()?.$1 == '-') {
        p++;
        return -unary();
      }
      return primary();
    }

    double factor() {
      final b = unary();
      if (peek()?.$1 == '^') {
        p++;
        return math.pow(b, factor()).toDouble();
      }
      return b;
    }

    double term() {
      var v = factor();
      while (peek() != null && const {'*', '/', '%'}.contains(peek()!.$1)) {
        final op = toks[p++].$1;
        final r = factor();
        v = op == '*' ? v * r : (op == '/' ? v / r : v.remainder(r));
      }
      return v;
    }

    expr = () {
      var v = term();
      while (peek() != null && (peek()!.$1 == '+' || peek()!.$1 == '-')) {
        final op = toks[p++].$1;
        final r = term();
        v = op == '+' ? v + r : v - r;
      }
      return v;
    };

    try {
      final v = expr();
      if (p < toks.length) throw FormatException('unexpected ${toks[p].$1}');
      return FormulaResult.ok(v, refs);
    } on FormatException catch (e) {
      return FormulaResult.fail(e.message, refs);
    }
  }

  static double _fn(String name, List<double> a) => switch (name) {
        'min' => a.reduce(math.min),
        'max' => a.reduce(math.max),
        'round' => (() {
            final k = math.pow(10, a.length > 1 ? a[1] : 0);
            return (a[0] * k).roundToDouble() / k;
          })(),
        'floor' => a[0].floorToDouble(),
        'ceil' => a[0].ceilToDouble(),
        'abs' => a[0].abs(),
        _ => throw FormatException('unknown function $name'),
      };

  static List<(String, Object?)> _tokenize(String s) {
    final out = <(String, Object?)>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c.trim().isEmpty) {
        i++;
        continue;
      }
      if (RegExp(r'[0-9.]').hasMatch(c)) {
        final m = RegExp(r'^\d*\.?\d+(?:e[+-]?\d+)?', caseSensitive: false).firstMatch(s.substring(i));
        if (m == null) throw FormatException('bad number at $i');
        out.add(('num', double.parse(m[0]!)));
        i += m[0]!.length;
        continue;
      }
      if (c == '{') {
        final end = s.indexOf('}', i);
        if (end < 0) throw const FormatException('unclosed {');
        final name = s.substring(i + 1, end).trim();
        if (name.isEmpty) throw const FormatException('empty {}');
        out.add(('ref', name));
        i = end + 1;
        continue;
      }
      if (RegExp(r'[a-z]', caseSensitive: false).hasMatch(c)) {
        final m = RegExp(r'^[a-z]+', caseSensitive: false).firstMatch(s.substring(i))!;
        out.add(('fn', m[0]!.toLowerCase()));
        i += m[0]!.length;
        continue;
      }
      if ('+-*/%^(),'.contains(c)) {
        out.add((c, null));
        i++;
        continue;
      }
      throw FormatException('unexpected "$c"');
    }
    return out;
  }

  /// The value a formula field shows for one object (EXE formulaValue).
  /// [fields]: (id, name, type, optionsJson). [values]: template id → raw.
  /// A formula may read another; a cycle is an error, not a hang. An empty
  /// or non-numeric input makes the result empty, not 0 — a missing HP must
  /// not read as HP 0.
  static FormulaResult valueOf(
    ({int id, String name, String type, String? options}) field,
    List<({int id, String name, String type, String? options})> fields,
    Map<int, String?> values, [
    Set<int> seen = const {},
  ]) {
    if (seen.contains(field.id)) return const FormulaResult.fail('cycle');
    var expr = '';
    try {
      final o = jsonDecode(field.options ?? '{}');
      if (o is Map && o['expr'] is String) expr = o['expr'] as String;
    } catch (_) {}
    final byName = {for (final f in fields) f.name.trim().toLowerCase(): f};
    final next = {...seen, field.id};
    FormulaResult? inner;
    final r = eval(expr, (name) {
      final f = byName[name.trim().toLowerCase()];
      if (f == null) return null;
      if (f.type == 'formula') {
        final sub = valueOf(f, fields, values, next);
        if (!sub.ok) {
          inner = sub;
          return double.nan;
        }
        return sub.value ?? double.nan;
      }
      if (f.type == 'checkbox') return values[f.id] == '1' ? 1 : 0;
      final raw = (values[f.id] ?? '').trim();
      return raw.isEmpty ? double.nan : (double.tryParse(raw) ?? double.nan);
    });
    if (inner != null) return inner!;
    if (r.ok && (r.value == null || !r.value!.isFinite)) return FormulaResult.ok(null, r.refs);
    return r;
  }
}

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Story variables, conditions and set-ops (V5.md §11.6) — the port of EXE
/// mod/narrator-logic.js and db/narrator.js getStoryVariables.
///
///   a variable   a Classifier object in a "story variables" category, its
///                fields marked by options.role varType / varDefault
///   a condition  on a choice option: ALL of [{key, op, value}] must hold
///   a set-op     on a choice option: applied in order when it is picked
class StoryVar {
  final String key;
  final String name;
  final String type; // number | bool | text
  final String initial;
  Object value;
  StoryVar(this.key, this.name, this.type, this.initial) : value = StoryLogic.coerce(type, initial);

  String get text => '$value';
}

class StoryLogic {
  static const condOps = ['==', '!=', '>', '>=', '<', '<='];
  static const setOps = ['=', '+=', '-=', 'toggle'];
  static const varTypes = ['number', 'bool', 'text'];

  static List<Map<String, dynamic>> parse(String? json) {
    try {
      final v = jsonDecode(json == null || json.isEmpty ? '[]' : json);
      return v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : [];
    } catch (_) {
      return [];
    }
  }

  static Object coerce(String type, Object? v) {
    if (type == 'number') {
      final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
      return n != null && n.isFinite ? (n == n.roundToDouble() ? n.toInt() : n) : 0;
    }
    if (type == 'bool') return v == true || RegExp(r'^(true|1|yes)$', caseSensitive: false).hasMatch('${v ?? ''}'.trim());
    return '${v ?? ''}';
  }

  static int _cmp(Object a, Object b) {
    if (a is num && b is num) return a.compareTo(b);
    return '$a'.compareTo('$b');
  }

  /// An unknown variable fails the condition.
  static bool holds(List<Map<String, dynamic>> list, Map<String, StoryVar> vars) => list.every((c) {
        final v = vars[c['key']];
        if (v == null) return false;
        final a = v.value, b = coerce(v.type, c['value']);
        return switch (c['op']) {
          '==' => a == b,
          '!=' => a != b,
          '>' => _cmp(a, b) > 0,
          '>=' => _cmp(a, b) >= 0,
          '<' => _cmp(a, b) < 0,
          '<=' => _cmp(a, b) <= 0,
          _ => false,
        };
      });

  static void apply(List<Map<String, dynamic>> list, Map<String, StoryVar> vars) {
    for (final s in list) {
      final v = vars[s['key']];
      if (v == null) continue;
      switch (s['op']) {
        case 'toggle':
          if (v.type == 'bool') v.value = !(v.value as bool);
        case '=':
          v.value = coerce(v.type, s['value']);
        case '+=' || '-=':
          if (v.type == 'number') {
            final d = coerce('number', s['value']) as num;
            final r = (v.value as num) + (s['op'] == '-=' ? -d : d);
            v.value = r == r.roundToDouble() ? r.toInt() : r;
          } else if (v.type == 'text' && s['op'] == '+=') {
            v.value = '${v.value}${s['value'] ?? ''}';
          }
      }
    }
  }

  /// Every story variable of a Nexus, at its default.
  static Future<Map<String, StoryVar>> variables(Database db, int nexusId) async {
    Future<Map<String, Object?>?> roleTpl(int moduleId, String role) async {
      final r = await db.rawQuery(
          "SELECT id, options FROM classifier_template WHERE module_ref=? AND object_ref IS NULL "
          "AND options LIKE ? ORDER BY id LIMIT 1",
          [moduleId, '%"role":"$role"%']);
      return r.isEmpty ? null : r.first;
    }

    Future<String?> val(int obj, int tpl) async {
      final r = await db.rawQuery(
          'SELECT attribute_value AS v FROM classifier_attribute WHERE object_ref=? AND template_ref=?', [obj, tpl]);
      return r.isEmpty ? null : r.first['v'] as String?;
    }

    final out = <String, StoryVar>{};
    final mods = await db.rawQuery(
        "SELECT id FROM module WHERE nexus_ref=? AND kind='classifier' ORDER BY display_order, id", [nexusId]);
    for (final m in mods) {
      final mid = m['id'] as int;
      final def = await roleTpl(mid, 'varDefault');
      if (def == null) continue;
      final typ = await roleTpl(mid, 'varType');
      var choices = <String>[];
      try {
        final o = jsonDecode(typ?['options'] as String? ?? '{}');
        if (o is Map && o['choices'] is List) choices = [for (final c in o['choices'] as List) '$c'];
      } catch (_) {}
      for (final o in await db.rawQuery(
          'SELECT id, name FROM classifier_object WHERE module_ref=? ORDER BY display_order, id', [mid])) {
        final oid = o['id'] as int;
        final initial = await val(oid, def['id'] as int) ?? '';
        final tv = typ == null ? null : await val(oid, typ['id'] as int);
        // The select's position, not its (translatable) text, says the type.
        final at = tv == null ? -1 : choices.indexOf(tv);
        var type = at >= 0 && at < varTypes.length ? varTypes[at] : null;
        type ??= RegExp(r'^(true|false)$', caseSensitive: false).hasMatch(initial)
            ? 'bool'
            : (initial.isNotEmpty && double.tryParse(initial) != null ? 'number' : 'text');
        out['cobj_$oid'] = StoryVar('cobj_$oid', o['name'] as String, type, initial);
      }
    }
    return out;
  }
}

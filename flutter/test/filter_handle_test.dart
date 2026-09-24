// The `handle` filter field (desktop v5 Part 4, DraconDex-APP docs/V5.md
// §8.9). The desktop added it to its filter engine; a filterDef saved there
// has to read — and re-save — the same way here, or the rule's value is
// dropped the first time this app writes the filter back.
import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/data/models/viewer_model.dart';

IndexedItem _module(int id, String name, {String? handle}) => IndexedItem(
      key: 'module_$id',
      itemKind: 'module',
      name: name,
      moduleId: id,
      moduleName: name,
      moduleKind: 'classifier',
      handle: handle,
    );

void main() {
  final items = [
    _module(1, 'Heroes', handle: 'cast'),
    _module(2, 'Villains', handle: 'castaways'),
    _module(3, 'Places'),
    const IndexedItem(
      key: 'cobj_9',
      itemKind: 'object',
      name: 'cast',
      moduleId: 1,
      moduleName: 'Heroes',
      moduleKind: 'classifier',
    ),
  ];

  FilterDef def(String op, String value) => FilterDef(groups: [
        FilterGroup(rules: [FilterRule(field: 'handle', op: op, value: value)]),
      ]);

  test('handle matches module rows only, and ignores a leading @', () {
    expect(applyFilter(items, def('is', '@cast'), 0).map((i) => i.key), ['module_1']);
    expect(applyFilter(items, def('startsWith', 'cast'), 0).map((i) => i.key),
        ['module_1', 'module_2']);
  });

  test('a module without a handle never matches, even isNot', () {
    expect(applyFilter(items, def('isNot', 'cast'), 0).map((i) => i.key), ['module_2']);
  });

  test('the rule keeps its op and value through a save', () {
    final round = FilterDef.fromJson(def('contains', 'away').toJson());
    final r = round.groups.single.rules.single;
    expect([r.field, r.op, r.value], ['handle', 'contains', 'away']);
  });
}

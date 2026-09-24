// Every module kind carries its category (DraconDex-APP docs/V5.md §9.2),
// matching the desktop's KIND_CATEGORY. The `required` constructor argument
// already makes a missing category a compile error; this pins the values.
import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/data/models/module_model.dart';

void main() {
  test('every kind is registered, with the §9.2 category', () {
    expect(moduleKindInfo.keys.toSet(), ModuleKind.values.toSet());
    final by = <ModuleCategory, List<String>>{};
    for (final e in moduleKindInfo.entries) {
      expect(e.value.kind, e.key);
      by.putIfAbsent(e.value.category, () => []).add(e.key.id);
    }
    expect(by[ModuleCategory.structure], ['collector']);
    // v5 (V5.md §3) folded viewer + connector into exhibitor.
    expect((by[ModuleCategory.view]!..sort()), ['exhibitor', 'manager']);
    expect(by[ModuleCategory.data]!.length, 12);
    // Notes live in module.description, yet they are data (§9.1).
    expect(moduleKindInfo[ModuleKind.inspector]!.category, ModuleCategory.data);
    expect(moduleKindInfo[ModuleKind.drafter]!.category, ModuleCategory.data);
  });

  test('pre-v5 kind ids still read, as the Exhibitor', () {
    expect(ModuleKind.fromId('viewer'), ModuleKind.exhibitor);
    expect(ModuleKind.fromId('connector'), ModuleKind.exhibitor);
    expect(ModuleKind.fromId('nonsense'), ModuleKind.collector);
  });
}

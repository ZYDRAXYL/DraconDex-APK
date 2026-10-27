import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/data/services/linked_modules.dart';

/// Procress 28 part 6 — the same cases as EXE electron/test/linked-modules.test.mjs.
void main() {
  // module 1 Author, 2 Cast (objects cobj_20, cobj_21), 3 Places (cobj_30)
  int? owner(String k) => switch (k) {
        'module_1' => 1,
        'module_2' || 'cobj_20' || 'cobj_21' => 2,
        'module_3' || 'cobj_30' => 3,
        _ => null,
      };
  List<(int, int?, bool)> plain(List<LinkedModule> ls) => [for (final e in ls) (e.id, e.relationId, e.wiki)];

  test('a module relation links both ends; an object relation does not', () {
    const rels = [(7, 'module_1', 'module_2'), (8, 'cobj_20', 'cobj_30')];
    expect(plain(linkedModulesFrom(1, relations: rels, wikiLinks: const [], ownerOf: owner)), [(2, 7, false)]);
    expect(plain(linkedModulesFrom(2, relations: rels, wikiLinks: const [], ownerOf: owner)), [(1, 7, false)]);
    expect(linkedModulesFrom(3, relations: rels, wikiLinks: const [], ownerOf: owner), isEmpty);
  });

  test('a [[link]] to a module or one of its objects links them, both ways', () {
    const links = [('module_1', 'cobj_20'), ('module_1', 'module_3')];
    expect(plain(linkedModulesFrom(1, relations: const [], wikiLinks: links, ownerOf: owner)), [(2, null, true), (3, null, true)]);
    expect(plain(linkedModulesFrom(2, relations: const [], wikiLinks: links, ownerOf: owner)), [(1, null, true)]);
  });

  test('a link inside one module, or to itself, links nothing; both kinds merge', () {
    expect(linkedModulesFrom(2, relations: const [], wikiLinks: const [('cobj_20', 'cobj_21'), ('cobj_20', 'module_2')], ownerOf: owner), isEmpty);
    expect(plain(linkedModulesFrom(1, relations: const [(7, 'module_2', 'module_1')], wikiLinks: const [('cobj_20', 'module_1')], ownerOf: owner)), [(2, 7, true)]);
  });
}

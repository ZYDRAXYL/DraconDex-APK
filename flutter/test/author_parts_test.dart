import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/features/page/views/author_parts.dart';

/// Procress 28 part 5 — the same cases as EXE electron/test/author-parts.test.mjs.
void main() {
  const ch = [10, 11, 12];
  String seq(List<AuthorPart> parts) => [for (final r in authorRows(ch, parts)) r.part?.id ?? 'c${r.chapter}'].join(' ');

  test('rows: a part before chapter `at`; past the end = after the last; same `at` keeps array order', () {
    expect(seq(const [AuthorPart('A', 0), AuthorPart('B', 2), AuthorPart('C', 2), AuthorPart('D', 9)]), 'A c10 c11 B C c12 D');
    expect(seq(const []), 'c10 c11 c12');
  });

  test('a drag in the row list reads back as positions', () {
    final rows = authorRows(ch, const [AuthorPart('A', 0, 'One')]);
    final moved = [...rows];
    moved.insert(2, moved.removeAt(0)); // A below c11
    final parts = partsFromRows(moved);
    expect([for (final p in parts) (p.id, p.at, p.label)], [('A', 2, 'One')]);
  });

  test('deleting a chapter closes the parts after it up by one', () {
    expect([for (final p in partsAfterDelete(const [AuthorPart('A', 0), AuthorPart('B', 1), AuthorPart('C', 2)], 1)) p.at], [0, 1, 1]);
  });

  test('read and write the desktop\'s JSON; bad JSON is no parts', () {
    final p = parseAuthorParts('[{"id":"A","at":-3,"label":7},{"at":1}]');
    expect([for (final x in p) (x.id, x.at, x.label)], [('A', 0, '7')]);
    expect(parseAuthorParts('{oops'), isEmpty);
    expect(parseAuthorParts(null), isEmpty);
    expect(encodeAuthorParts(const []), '');
    expect(encodeAuthorParts(const [AuthorPart('A', 1, 'x')]), '[{"id":"A","at":1,"label":"x"}]');
  });
}

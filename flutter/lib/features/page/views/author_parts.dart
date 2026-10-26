import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../providers/db_providers.dart';

/// Procress 28 part 5 — an Author's Part dividers, the same module_ui row the
/// desktop writes (EXE mod/author-parts.js): `authorParts` =
/// `[{id, at, label}]`, `at` = the number of chapters before it. A position,
/// not a chapter id — nothing to remap when a snapshot moves between
/// devices. Parts with the same `at` keep their array order.
class AuthorPart {
  final String id;
  final int at;
  final String label;
  const AuthorPart(this.id, this.at, [this.label = '']);
  AuthorPart copyWith({int? at, String? label}) => AuthorPart(id, at ?? this.at, label ?? this.label);
  Map<String, Object> toJson() => {'id': id, 'at': at, 'label': label};
}

List<AuthorPart> parseAuthorParts(String? raw) {
  try {
    final v = jsonDecode(raw == null || raw.isEmpty ? '[]' : raw);
    if (v is! List) return const [];
    return [
      for (final p in v)
        if (p is Map && p['id'] is String) AuthorPart(p['id'] as String, math.max(0, (p['at'] as num?)?.toInt() ?? 0), '${p['label'] ?? ''}'),
    ];
  } catch (_) {
    return const [];
  }
}

String encodeAuthorParts(List<AuthorPart> parts) => parts.isEmpty ? '' : jsonEncode([for (final p in parts) p.toJson()]);

/// One row of the chapter list: a chapter (its index among chapters) or a part.
class AuthorRow<C> {
  final C? chapter;
  final int index;
  final AuthorPart? part;
  const AuthorRow.chapter(C this.chapter, this.index) : part = null;
  const AuthorRow.part(AuthorPart this.part)
      : chapter = null,
        index = -1;
}

/// The rows in order: a part before chapter `at` (past the end = after the
/// last chapter), then the chapter.
List<AuthorRow<C>> authorRows<C>(List<C> chapters, List<AuthorPart> parts) {
  final n = chapters.length;
  return [
    for (var i = 0; i <= n; i++) ...[
      for (final p in parts) if (math.min(p.at, n) == i) AuthorRow<C>.part(p),
      if (i < n) AuthorRow<C>.chapter(chapters[i], i),
    ],
  ];
}

/// Parts read back off a row order (after a drag): each one's `at` is the
/// number of chapters above it.
List<AuthorPart> partsFromRows<C>(List<AuthorRow<C>> rows) {
  var at = 0;
  final out = <AuthorPart>[];
  for (final r in rows) {
    if (r.part != null) {
      out.add(r.part!.copyWith(at: at));
    } else {
      at++;
    }
  }
  return out;
}

/// A chapter at [index] is gone: the parts after it close up by one.
List<AuthorPart> partsAfterDelete(List<AuthorPart> parts, int index) =>
    [for (final p in parts) p.at > index ? p.copyWith(at: p.at - 1) : p];

final authorPartsProvider = FutureProvider.autoDispose.family<List<AuthorPart>, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final r = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='authorParts'", [moduleId]);
  return parseAuthorParts(r.isEmpty ? null : r.first['ui_value'] as String?);
});

Future<void> saveAuthorParts(WidgetRef ref, int moduleId, List<AuthorPart> parts) async {
  final db = await ref.read(databaseProvider.future);
  await db.insert('module_ui', {'module_ref': moduleId, 'ui_key': 'authorParts', 'ui_value': encodeAuthorParts(parts)},
      conflictAlgorithm: ConflictAlgorithm.replace);
  ref.invalidate(authorPartsProvider(moduleId));
}

String newAuthorPartId() => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

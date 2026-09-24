import 'package:sqflite/sqflite.dart';

import '../services/wiki_service.dart';
import '../models/classifier_model.dart';

/// Data access for the Classifier kind: the module's field definitions, the
/// items under it, and the value each item holds for each field.
class ClassifierDao {
  final Database db;
  ClassifierDao(this.db);

  // ---- fields (classifier_template) ---------------------------------------

  /// Module-level fields only (object_ref IS NULL). Per-object template rows
  /// belong to the desktop side's overrides and are deliberately not mixed in.
  Future<List<ClassifierFieldModel>> getFields(int moduleRef) async {
    final rows = await db.rawQuery(
      'SELECT * FROM classifier_template WHERE module_ref=? AND object_ref IS NULL '
      'ORDER BY display_order, id',
      [moduleRef],
    );
    return rows.map(ClassifierFieldModel.fromMap).toList();
  }

  Future<int> createField({
    required int moduleRef,
    required String description,
    String attributeType = 'text',
  }) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM classifier_template '
      'WHERE module_ref=? AND object_ref IS NULL',
      [moduleRef],
    );
    return db.insert('classifier_template', {
      'module_ref': moduleRef,
      'description': description,
      'attribute_type': attributeType,
      'display_order': Sqflite.firstIntValue(orderRows) ?? 0,
    });
  }

  /// Name, type and per-type options at once — the field dialog's save.
  Future<void> updateField(int id, {required String description, required String type, String? options}) async {
    await db.rawUpdate(
      "UPDATE classifier_template SET description=?,attribute_type=?,options=?,update_at=datetime('now') WHERE id=?",
      [description, type, options, id],
    );
  }

  /// Every value of every item of a module, {object: {template: value}} —
  /// one query for a table instead of one per row.
  Future<Map<int, Map<int, String?>>> getModuleValues(int moduleRef) async {
    final rows = await db.rawQuery(
      'SELECT a.object_ref, a.template_ref, a.attribute_value FROM classifier_attribute a '
      'JOIN classifier_object o ON a.object_ref=o.id WHERE o.module_ref=?',
      [moduleRef],
    );
    final out = <int, Map<int, String?>>{};
    for (final r in rows) {
      (out[r['object_ref'] as int] ??= {})[r['template_ref'] as int] = r['attribute_value'] as String?;
    }
    return out;
  }

  /// A relation field's rows (EXE cls-field-types.js): ordinary relations,
  /// from `cobj_<object>`, typed `ctpl_<field>`.
  Future<List<({int id, String from, String to, int field})>> getFieldRelations(int moduleRef) async {
    final rows = await db.rawQuery(
      "SELECT r.id, r.from_key, r.to_key, r.rel_type FROM entity_relation r "
      "JOIN classifier_object o ON r.from_key='cobj_'||o.id "
      "WHERE o.module_ref=? AND r.rel_type LIKE 'ctpl\\_%' ESCAPE '\\' ORDER BY r.id",
      [moduleRef],
    );
    return [
      for (final r in rows)
        (
          id: r['id'] as int,
          from: r['from_key'] as String,
          to: r['to_key'] as String,
          field: int.tryParse((r['rel_type'] as String).substring(5)) ?? 0,
        ),
    ];
  }

  Future<void> addFieldRelation(int objectId, int fieldId, String toKey) async {
    final m = await db.rawQuery(
        'SELECT m.nexus_ref, m.id FROM classifier_object o JOIN module m ON o.module_ref=m.id WHERE o.id=?', [objectId]);
    if (m.isEmpty) return;
    await db.insert(
      'entity_relation',
      {
        'nexus_ref': m.first['nexus_ref'],
        'module_ref': m.first['id'],
        'from_key': 'cobj_$objectId',
        'to_key': toKey,
        'rel_type': 'ctpl_$fieldId',
        'directed': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteRelation(int id) async {
    await db.delete('entity_relation', where: 'id=?', whereArgs: [id]);
  }

  Future<void> renameField(int id, String description) async {
    await db.rawUpdate(
      "UPDATE classifier_template SET description=?,update_at=datetime('now') WHERE id=?",
      [description, id],
    );
  }

  /// Deleting a field takes its values with it — classifier_attribute
  /// references template_ref ON DELETE CASCADE.
  Future<void> deleteField(int id) async {
    await db.delete('classifier_template', where: 'id=?', whereArgs: [id]);
  }

  // ---- items (classifier_object) ------------------------------------------

  Future<List<ClassifierItemModel>> getItems(int moduleRef) async {
    final rows = await db.rawQuery('''
      SELECT co.*, uc.color_code FROM classifier_object co
      LEFT JOIN use_color uc ON co.color = uc.id
      WHERE co.module_ref=? ORDER BY co.display_order, co.name COLLATE NOCASE
    ''', [moduleRef]);
    return rows.map(ClassifierItemModel.fromMap).toList();
  }

  Future<int> createItem({required int moduleRef, required String name}) async {
    final orderRows = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order),-1)+1 AS next FROM classifier_object WHERE module_ref=?',
      [moduleRef],
    );
    final id = await db.insert('classifier_object', {
      'module_ref': moduleRef,
      'name': name,
      'display_order': Sqflite.firstIntValue(orderRows) ?? 0,
    });
    await WikiService.resolveDangling(db, name, await WikiService.nexusOfModule(db, moduleRef));
    return id;
  }

  Future<void> updateItem(int id, {required String name, String? note}) async {
    final old = await db.rawQuery(
        'SELECT o.name, m.nexus_ref FROM classifier_object o JOIN module m ON o.module_ref=m.id WHERE o.id=?', [id]);
    await db.rawUpdate(
      "UPDATE classifier_object SET name=?,note=?,update_at=datetime('now') WHERE id=?",
      [name, note, id],
    );
    await WikiService.reindexSource(db, 'cobj', id);
    if (old.isNotEmpty) {
      await WikiService.renamed(db, 'cobj_$id', old.first['name'] as String?, name, old.first['nexus_ref'] as int?);
    }
  }

  Future<void> deleteItem(int id) async {
    await db.delete('classifier_object', where: 'id=?', whereArgs: [id]);
  }

  // ---- values (classifier_attribute) --------------------------------------

  /// Every value this item holds, as {template_ref: attribute_value}. Missing
  /// keys mean the field was never filled in, which is distinct from ''.
  Future<Map<int, String?>> getValues(int objectRef) async {
    final rows = await db.query(
      'classifier_attribute',
      columns: ['template_ref', 'attribute_value'],
      where: 'object_ref=?',
      whereArgs: [objectRef],
    );
    return {
      for (final r in rows) r['template_ref'] as int: r['attribute_value'] as String?,
    };
  }

  /// UNIQUE(object_ref, template_ref) makes this an upsert rather than an
  /// insert-or-update dance.
  Future<void> setValue({
    required int objectRef,
    required int templateRef,
    String? value,
  }) async {
    await db.insert(
      'classifier_attribute',
      {'object_ref': objectRef, 'template_ref': templateRef, 'attribute_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // A text field's value is part of the object's linkable text.
    await WikiService.reindexSource(db, 'cobj', objectRef);
  }
}

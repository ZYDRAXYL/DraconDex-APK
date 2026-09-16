// Classifier-kind content models.
//
// Three tables work together, mirroring Electron's mod/classifier.js:
//   classifier_template   the field definitions for this module
//   classifier_object     the items being classified
//   classifier_attribute  one value per (object, template), UNIQUE on the pair
//
// classifier_template.object_ref is nullable; a null one is a module-level
// field, which is what this editor creates. Per-object template overrides
// exist in the schema for the desktop side and are left alone here rather
// than half-supported.

class ClassifierFieldModel {
  final int id;
  final int moduleRef;
  final String description;
  final String attributeType;
  final int order;

  const ClassifierFieldModel({
    required this.id,
    required this.moduleRef,
    required this.description,
    this.attributeType = 'text',
    this.order = 0,
  });

  factory ClassifierFieldModel.fromMap(Map<String, dynamic> m) => ClassifierFieldModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        description: m['description'] as String,
        attributeType: m['attribute_type'] as String? ?? 'text',
        order: m['display_order'] as int? ?? 0,
      );
}

class ClassifierItemModel {
  final int id;
  final int moduleRef;
  final String name;
  final String? note;
  final String? colorCode;
  final int order;

  const ClassifierItemModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.note,
    this.colorCode,
    this.order = 0,
  });

  factory ClassifierItemModel.fromMap(Map<String, dynamic> m) => ClassifierItemModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        note: m['note'] as String?,
        colorCode: m['color_code'] as String?,
        order: m['display_order'] as int? ?? 0,
      );
}

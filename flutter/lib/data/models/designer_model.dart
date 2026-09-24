// Designer-kind content models: a free-form diagram board.
//
// Unlike Narrator — where pos_x/pos_y belong to the desktop's layout and this
// front-end leaves them alone — a Designer's coordinates ARE its content. A
// board with no positions is not a board, so this editor reads and writes
// design_node.x/y directly.
//
// design_node.shape has deliberately no CHECK constraint upstream: the shape
// vocabulary lives in the renderer, so SQLite never has to rebuild the table
// to learn a new one. Unknown shapes therefore have to render as something
// rather than be rejected.

class DesignNodeModel {
  final int id;
  final int moduleRef;
  final String shape;
  final double x;
  final double y;
  final String? text;

  /// Stored as free text (a CSS colour on the desktop), not a use_color id.
  final String? color;

  /// Comic pages (V5.md §11.6, EXE designer-comic.js): a panel shows what
  /// [linkerKey] names (a Sketcher page), a balloon's [linkerKey] is its
  /// speaker. NULL [w]/[h] is the shape's natural size; [readOrder] NULL is
  /// not part of the reading order.
  final String? linkerKey;
  final double? w;
  final double? h;
  final int? readOrder;

  const DesignNodeModel({
    required this.id,
    required this.moduleRef,
    this.shape = 'box',
    this.x = 0,
    this.y = 0,
    this.text,
    this.color,
    this.linkerKey,
    this.w,
    this.h,
    this.readOrder,
  });

  factory DesignNodeModel.fromMap(Map<String, dynamic> m) => DesignNodeModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        shape: m['shape'] as String? ?? 'box',
        // REAL columns can come back as int when the stored value is whole.
        x: (m['x'] as num?)?.toDouble() ?? 0,
        y: (m['y'] as num?)?.toDouble() ?? 0,
        text: m['node_text'] as String?,
        color: m['color'] as String?,
        linkerKey: m['linker_key'] as String?,
        w: (m['w'] as num?)?.toDouble(),
        h: (m['h'] as num?)?.toDouble(),
        readOrder: m['read_order'] as int?,
      );
}

class DesignEdgeModel {
  final int id;
  final int fromRef;
  final int toRef;
  final String? label;

  const DesignEdgeModel({
    required this.id,
    required this.fromRef,
    required this.toRef,
    this.label,
  });

  factory DesignEdgeModel.fromMap(Map<String, dynamic> m) => DesignEdgeModel(
        id: m['id'] as int,
        fromRef: m['from_ref'] as int,
        toRef: m['to_ref'] as int,
        label: m['label'] as String?,
      );
}

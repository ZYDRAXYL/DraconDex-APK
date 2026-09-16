import 'dart:convert';

// Sketcher-kind content models: freehand pages and the strokes on them.
//
// sketch_stroke.points is a FLAT JSON number array — [x0,y0,x1,y1,...], not a
// list of objects — matching the desktop's mod/sketcher.js exactly. It writes
// `JSON.stringify(rounded)` where rounded is one-decimal, and reads with
// moveTo(pts[0],pts[1]) then lineTo over successive pairs. Getting this shape
// wrong would not fail loudly; it would silently produce drawings the other
// front-end cannot render, so it is replicated rather than reinvented.

/// The desktop's fixed drawing surface (SK_W x SK_H in mod/sketcher.js).
/// Coordinates are stored in this space on both front-ends, so a sketch drawn
/// on a phone lines up when opened on the desktop.
const double kSketchWidth = 1600;
const double kSketchHeight = 1100;

/// The desktop's palette and pen widths (SK_COLORS / SK_WIDTHS), kept
/// identical so a stroke drawn here looks the same there.
const List<String> kSketchColors = ['#e879f9', '#facc15', '#38bdf8', '#f8fafc'];
const List<double> kSketchWidths = [2, 4, 7];

class SketchPageModel {
  final int id;
  final int moduleRef;
  final String name;
  final int order;

  const SketchPageModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.order = 0,
  });

  factory SketchPageModel.fromMap(Map<String, dynamic> m) => SketchPageModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        order: m['page_order'] as int? ?? 0,
      );
}

class SketchStrokeModel {
  final int id;
  final int pageRef;
  final String? color;
  final double width;

  /// Decoded flat coordinates: [x0,y0,x1,y1,...].
  final List<double> points;

  const SketchStrokeModel({
    required this.id,
    required this.pageRef,
    this.color,
    this.width = 3,
    this.points = const [],
  });

  factory SketchStrokeModel.fromMap(Map<String, dynamic> m) {
    List<double> pts = const [];
    try {
      final raw = jsonDecode(m['points'] as String? ?? '[]');
      if (raw is List) pts = raw.whereType<num>().map((n) => n.toDouble()).toList();
    } on FormatException {
      // A malformed stroke is dropped, not fatal: one bad row should not
      // take the whole page down with it.
    }
    return SketchStrokeModel(
      id: m['id'] as int,
      pageRef: m['page_ref'] as int,
      color: m['color'] as String?,
      width: (m['width'] as num?)?.toDouble() ?? 3,
      points: pts,
    );
  }
}

/// Encodes a flat coordinate list the way the desktop does: one decimal
/// place, and never fewer than two points — mod/sketcher.js pads a tap with
/// a +0.5 offset so a dot still has a segment to draw.
String encodeStrokePoints(List<double> pts) {
  final rounded = pts.map((v) => (v * 10).round() / 10).toList();
  if (rounded.length < 4 && rounded.length >= 2) {
    rounded.addAll([rounded[0] + 0.5, rounded[1] + 0.5]);
  }
  return jsonEncode(rounded);
}

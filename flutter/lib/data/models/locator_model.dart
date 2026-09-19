// Locator-kind content models: a module's map and the polygon areas on it.
//
//   map         one row per module — "a Locator module IS its map", created
//               on first open, exactly as the desktop's
//               api.map.getOrCreateModuleMap does
//   map_area    a named polygon
//   map_point   its vertices, ordered by point_order
//
// The desktop renders these on a Konva stage with its own pan and zoom, so
// x/y are free world coordinates with no fixed canvas behind them — unlike
// Sketcher, which has a real 1600x1100 surface. Coordinates are therefore
// stored exactly as given and never normalised to a mobile viewport; doing
// so would silently move every area when the map is next opened on desktop.

class MapModel {
  final int id;
  final int? moduleRef;
  final String? name;

  const MapModel({required this.id, this.moduleRef, this.name});

  factory MapModel.fromMap(Map<String, dynamic> m) => MapModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int?,
        name: m['map_name'] as String?,
      );
}

class MapPointModel {
  final int id;
  final int areaId;
  final int order;
  final double x;
  final double y;

  const MapPointModel({
    required this.id,
    required this.areaId,
    this.order = 0,
    required this.x,
    required this.y,
  });

  factory MapPointModel.fromMap(Map<String, dynamic> m) => MapPointModel(
        id: m['id'] as int,
        areaId: m['area_id'] as int,
        order: m['point_order'] as int? ?? 0,
        // REAL columns come back as int when the stored value is whole.
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
      );
}

class MapAreaModel {
  final int id;
  final int mapId;
  final String? name;
  final String? colorCode;
  final List<MapPointModel> points;

  const MapAreaModel({
    required this.id,
    required this.mapId,
    this.name,
    this.colorCode,
    this.points = const [],
  });

  factory MapAreaModel.fromMap(Map<String, dynamic> m, List<MapPointModel> pts) =>
      MapAreaModel(
        id: m['id'] as int,
        mapId: m['map_id'] as int,
        name: m['area_name'] as String?,
        colorCode: m['color_code'] as String?,
        points: pts,
      );

  /// A polygon needs three vertices; fewer is a partially drawn area that
  /// should show as its dots only, not as a filled shape.
  bool get isPolygon => points.length >= 3;
}

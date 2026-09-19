// Wanderer-kind content models: timeline events pinned onto a map.
//
// map_event is the join. It belongs to the Wanderer module (module_ref) and
// optionally points at a timeline_event (event_ref) and a map_area
// (area_ref), both ON DELETE SET NULL — so deleting an event or an area
// leaves the pin in place with its link cleared rather than removing it.
// This editor honours that: an unlinked pin is a legitimate state, not an
// error to clean up.
//
// Coordinates follow Locator's rule: free world space, stored verbatim,
// never rescaled to a mobile viewport.

class MapEventModel {
  final int id;
  final int moduleRef;
  final int? eventRef;
  final int? areaRef;
  final String? label;
  final double x;
  final double y;

  /// Resolved in the DAO's join so a pin can show what it points at without
  /// a lookup per marker. Null when the pin has no link, or when the event
  /// it pointed at was deleted.
  final String? eventName;

  const MapEventModel({
    required this.id,
    required this.moduleRef,
    this.eventRef,
    this.areaRef,
    this.label,
    this.x = 0,
    this.y = 0,
    this.eventName,
  });

  /// What to show on the marker: its own label first, then the linked event's
  /// name, and only then nothing.
  String? get displayName {
    if (label != null && label!.isNotEmpty) return label;
    if (eventName != null && eventName!.isNotEmpty) return eventName;
    return null;
  }

  factory MapEventModel.fromMap(Map<String, dynamic> m) => MapEventModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        eventRef: m['event_ref'] as int?,
        areaRef: m['area_ref'] as int?,
        label: m['label'] as String?,
        x: (m['x'] as num?)?.toDouble() ?? 0,
        y: (m['y'] as num?)?.toDouble() ?? 0,
        eventName: m['event_name'] as String?,
      );
}

/// A timeline event offered in the link picker, with the module it lives in
/// so two events sharing a name stay distinguishable.
class LinkableEvent {
  final int id;
  final String name;
  final String moduleName;

  const LinkableEvent({required this.id, required this.name, required this.moduleName});

  factory LinkableEvent.fromMap(Map<String, dynamic> m) => LinkableEvent(
        id: m['id'] as int,
        name: (m['event_name'] as String?) ?? '',
        moduleName: (m['module_name'] as String?) ?? '',
      );
}

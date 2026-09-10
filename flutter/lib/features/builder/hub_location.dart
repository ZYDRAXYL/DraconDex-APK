/// Where inside the Hub the router currently is, read back out of the path.
///
/// The tablet shell shows the tree beside the content instead of drilling
/// into it one screen at a time, so the hub panel has to know which row to
/// mark as the open one — and all it is given is the location string the
/// ShellRoute hands down.
class HubLocation {
  /// null when the current route is not a Hub route at all (the Nexus list
  /// itself, or one of the utility pages).
  final int? nexusId;

  /// null at a Nexus root, i.e. `/hub/3`.
  final int? moduleId;

  const HubLocation({this.nexusId, this.moduleId});

  static const HubLocation none = HubLocation();

  bool get isHome => nexusId == null;

  /// Parses `/`, `/hub/3` and `/hub/3/module/12`. Anything else — an
  /// unrecognised or malformed path — resolves to [none] rather than
  /// throwing: this only drives a highlight.
  factory HubLocation.parse(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2 || parts[0] != 'hub') return none;
    final nexusId = int.tryParse(parts[1]);
    if (nexusId == null) return none;
    if (parts.length >= 4 && parts[2] == 'module') {
      return HubLocation(nexusId: nexusId, moduleId: int.tryParse(parts[3]));
    }
    return HubLocation(nexusId: nexusId);
  }
}

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

  /// An element page inside [moduleId] (`cobj_12`), i.e.
  /// `/hub/3/module/12/item/cobj_12` — null on the module's own page.
  final String? itemKey;

  const HubLocation({this.nexusId, this.moduleId, this.itemKey});

  static const HubLocation none = HubLocation();

  bool get isHome => nexusId == null;

  /// An entity key with a prefix and a row id, the shape every element key
  /// in the vault has.
  static final itemKeyPattern = RegExp(r'^[a-z]+_\d+$');

  /// Parses `/`, `/hub/3`, `/hub/3/module/12` and
  /// `/hub/3/module/12/item/cobj_4`. Anything else — an
  /// unrecognised or malformed path — resolves to [none] rather than
  /// throwing: this only drives a highlight.
  factory HubLocation.parse(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2 || parts[0] != 'hub') return none;
    final nexusId = int.tryParse(parts[1]);
    if (nexusId == null) return none;
    if (parts.length >= 4 && parts[2] == 'module') {
      final moduleId = int.tryParse(parts[3]);
      final item = parts.length >= 6 && parts[4] == 'item' && moduleId != null && itemKeyPattern.hasMatch(parts[5])
          ? parts[5]
          : null;
      return HubLocation(nexusId: nexusId, moduleId: moduleId, itemKey: item);
    }
    return HubLocation(nexusId: nexusId);
  }
}

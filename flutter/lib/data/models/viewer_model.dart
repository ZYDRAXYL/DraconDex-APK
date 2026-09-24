// Viewer/Connector shared models: the vault-wide item index and the saved
// filter that selects from it.
//
// Item keys match the desktop's exactly — module_/cobj_/tlev_/sdlg_/bchp_/
// chss_ followed by the row id — because entity_relation.from_key/to_key
// store these strings. A relation authored here has to be the same edge the
// Electron front-end sees, so the prefixes are a compatibility contract, not
// an internal detail.

/// One row in the vault-wide index a Viewer or Connector filters over.
class IndexedItem {
  final String key;

  /// What sort of row this is: object, event, dialogue, chapter, chat, module.
  final String itemKind;
  final String name;

  /// The module that owns this item (for a module row, itself).
  final int moduleId;
  final String moduleName;

  /// The owning module's ModuleKind id — what the filter's `kind` rule tests,
  /// which is the module's kind, not [itemKind].
  final String moduleKind;
  final int? moduleParentId;
  final String? colorCode;

  /// The module's @handle — module rows only (null everywhere else), which
  /// is what the `handle` filter rule tests (desktop v5 Part 4, V5.md §8.9).
  final String? handle;

  /// Tag names on this item. Only modules and timeline events carry tags:
  /// module_hashtag and event_hashtag exist, while object_hashtag references
  /// the legacy `object` table rather than classifier_object. Everything else
  /// indexes with an empty list, so a hashtag rule simply will not match it.
  final List<String> tags;

  const IndexedItem({
    required this.key,
    required this.itemKind,
    required this.name,
    required this.moduleId,
    required this.moduleName,
    required this.moduleKind,
    this.moduleParentId,
    this.colorCode,
    this.handle,
    this.tags = const [],
  });
}

/// One condition. `kind` carries [values] (a closed enum, no operator);
/// `childOf` carries [moduleId] (structural, no operator); `hashtag`,
/// `name` and `handle` carry [op] and [value]. The field list must match the
/// desktop's FILTER_FIELDS (DraconDex-EXE mod/filter.js) — a field one side
/// does not know is dropped when that side re-saves the filter.
class FilterRule {
  final String field;
  final String op;
  final String value;
  final List<String> values;
  final int? moduleId;

  const FilterRule({
    required this.field,
    this.op = 'contains',
    this.value = '',
    this.values = const [],
    this.moduleId,
  });

  factory FilterRule.fromJson(Map<String, dynamic> j) => FilterRule(
        field: j['field'] as String? ?? 'name',
        op: j['op'] as String? ?? 'contains',
        value: j['value'] as String? ?? '',
        values: (j['values'] as List?)?.map((e) => '$e').toList() ?? const [],
        moduleId: j['moduleId'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'field': field,
        if (field == 'hashtag' || field == 'name' || field == 'handle') ...{'op': op, 'value': value},
        if (field == 'kind') 'values': values,
        if (field == 'childOf') 'moduleId': moduleId,
      };
}

/// Rules are ANDed inside a group; groups are ORed with each other. That is
/// the desktop's Obsidian-style shape, kept identical so one filterDef reads
/// the same on both front-ends.
class FilterGroup {
  final List<FilterRule> rules;
  const FilterGroup({this.rules = const []});

  factory FilterGroup.fromJson(Map<String, dynamic> j) => FilterGroup(
        rules: (j['rules'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FilterRule.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'rules': rules.map((r) => r.toJson()).toList()};
}

class FilterDef {
  final List<FilterGroup> groups;
  const FilterDef({this.groups = const []});

  bool get isEmpty => groups.every((g) => g.rules.isEmpty);

  factory FilterDef.fromJson(Map<String, dynamic> j) => FilterDef(
        groups: (j['groups'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FilterGroup.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {'groups': groups.map((g) => g.toJson()).toList()};
}

bool _matchString(String haystack, String op, String needle) {
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase();
  switch (op) {
    case 'is':
      return h == n;
    case 'isNot':
      return h != n;
    case 'startsWith':
      return h.startsWith(n);
    case 'endsWith':
      return h.endsWith(n);
    case 'contains':
    default:
      return h.contains(n);
  }
}

bool _matchRule(IndexedItem it, FilterRule r) {
  switch (r.field) {
    case 'kind':
      return r.values.isEmpty || r.values.contains(it.moduleKind);
    case 'childOf':
      // The item's module is that module, or sits directly under it.
      return r.moduleId != null &&
          (it.moduleId == r.moduleId || it.moduleParentId == r.moduleId);
    case 'hashtag':
      if (r.op == 'isNot') return it.tags.every((t) => !_matchString(t, 'is', r.value));
      return it.tags.any((t) => _matchString(t, r.op, r.value));
    case 'name':
      return _matchString(it.name, r.op, r.value);
    case 'handle':
      // Same rule as the desktop's mod/filter.js: only a module has a handle,
      // and a leading '@' in the typed value is ignored.
      final h = it.handle;
      return h != null && h.isNotEmpty && _matchString(h, r.op, r.value.replaceFirst(RegExp(r'^@'), ''));
    default:
      return true;
  }
}

/// Applies [def] to [items], dropping the Viewer's own module so a lens never
/// lists itself. An empty definition selects nothing rather than everything —
/// a filter nobody has configured yet should read as "no results", not dump
/// the whole vault.
List<IndexedItem> applyFilter(List<IndexedItem> items, FilterDef def, int selfModuleId) {
  if (def.isEmpty) return const [];
  final selfKey = 'module_$selfModuleId';
  return items.where((it) {
    if (it.key == selfKey) return false;
    return def.groups.any((g) => g.rules.isNotEmpty && g.rules.every((r) => _matchRule(it, r)));
  }).toList();
}

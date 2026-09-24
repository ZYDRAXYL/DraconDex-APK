// One open page (APK V3, APP docs/APK-V3.md §10.2) — a Nexus root, one
// module inside it, or one element of a module. Persisted as JSON
// in SharedPreferences rather than in the vault DB: it is per-device UI
// history, not novel data, and must survive a DB import/restore untouched.

import 'dart:convert';

import 'module_model.dart';

class RecentView {
  final int nexusId;

  /// null = the Nexus root itself (the top of that tree).
  final int? moduleId;

  /// An element page (`cobj_12`, `tlev_4`, …) inside [moduleId] — null for
  /// the module's own page. Always null when [moduleId] is.
  final String? itemKey;

  /// Display name of the thing opened (module name, or Nexus name at root).
  final String title;

  /// Nexus name, shown as the second line when [moduleId] is set.
  final String nexusName;

  /// `ModuleKind.name` of the opened module — null at the Nexus root.
  final String? kindId;

  final String? colorCode;
  final DateTime openedAt;

  const RecentView({
    required this.nexusId,
    this.moduleId,
    this.itemKey,
    required this.title,
    required this.nexusName,
    this.kindId,
    this.colorCode,
    required this.openedAt,
  });

  /// Identity for dedupe — re-opening the same place moves the existing entry
  /// to the front instead of stacking a second copy of it.
  String get key => keyFor(nexusId, moduleId, itemKey);

  /// The same identity, buildable without an instance — lets a caller that
  /// only knows the ids (a delete handler) drop the matching entry without
  /// re-spelling the format. A module page keeps the pre-V3 form, so pages
  /// stored before element pages existed still match.
  static String keyFor(int nexusId, int? moduleId, [String? itemKey]) =>
      '$nexusId:${moduleId ?? 'root'}${itemKey == null ? '' : ':$itemKey'}';

  /// The go_router location this entry jumps back to.
  String get location => locationFor(nexusId, moduleId, itemKey);

  static String locationFor(int nexusId, int? moduleId, [String? itemKey]) {
    if (moduleId == null) return '/hub/$nexusId';
    final page = '/hub/$nexusId/module/$moduleId';
    return itemKey == null ? page : '$page/item/$itemKey';
  }

  ModuleKind? get kind => kindId == null ? null : ModuleKind.fromId(kindId!);

  RecentView copyWith({DateTime? openedAt}) => RecentView(
        nexusId: nexusId,
        moduleId: moduleId,
        itemKey: itemKey,
        title: title,
        nexusName: nexusName,
        kindId: kindId,
        colorCode: colorCode,
        openedAt: openedAt ?? this.openedAt,
      );

  Map<String, dynamic> toJson() => {
        'nexusId': nexusId,
        'moduleId': moduleId,
        if (itemKey != null) 'itemKey': itemKey,
        'title': title,
        'nexusName': nexusName,
        'kindId': kindId,
        'colorCode': colorCode,
        'openedAt': openedAt.toIso8601String(),
      };

  /// Returns null for a malformed entry (hand-edited prefs, a format change
  /// across versions) so one bad row can't take the whole history down.
  static RecentView? fromJson(Map<String, dynamic> m) {
    final nexusId = m['nexusId'];
    final title = m['title'];
    if (nexusId is! int || title is! String) return null;
    final moduleId = m['moduleId'] as int?;
    return RecentView(
      nexusId: nexusId,
      moduleId: moduleId,
      itemKey: moduleId == null ? null : m['itemKey'] as String?,
      title: title,
      nexusName: m['nexusName'] as String? ?? '',
      kindId: m['kindId'] as String?,
      colorCode: m['colorCode'] as String?,
      openedAt: DateTime.tryParse(m['openedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static String encodeList(List<RecentView> views) =>
      jsonEncode(views.map((v) => v.toJson()).toList());

  static List<RecentView> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecentView.fromJson)
          .whereType<RecentView>()
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

// Models for the v3 module system (Hub/Nexus nest) — mirrors electron's
// `nexus`/`module` tables (see docs/Architec.md §1). A Nexus holds one
// module tree; every node picks a `kind` and can itself hold children,
// which is what makes the Hub a drill-down file-explorer.

import 'package:flutter/material.dart';

class NexusModel {
  final int id;
  final String name;
  final String? memo;
  final int? colorId;
  final String? colorCode;
  final String updatedAt;

  const NexusModel({
    required this.id,
    required this.name,
    this.memo,
    this.colorId,
    this.colorCode,
    required this.updatedAt,
  });

  factory NexusModel.fromMap(Map<String, dynamic> m) => NexusModel(
        id: m['id'] as int,
        name: m['name'] as String,
        memo: m['memo'] as String?,
        colorId: m['color'] as int?,
        colorCode: m['color_code'] as String?,
        updatedAt: m['update_at'] as String? ?? '',
      );
}

/// The 15 module kinds (electron `module.kind` CHECK constraint). Each kind
/// picks the content area a module screen shows; every kind can still hold
/// children regardless, so nesting works the same everywhere.
enum ModuleKind {
  collector,
  manager,
  inspector,
  classifier,
  locator,
  chronicler,
  wanderer,
  narrator,
  author,
  scribe,
  drafter,
  viewer,
  connector,
  sketcher,
  designer,
  // V5.md §11.5 — random tables and dice. Registered so a vault that holds
  // one opens it by its real kind instead of falling back to collector;
  // the editor is not ported yet (contentImplemented: false below).
  diviner;

  String get id => name;

  static ModuleKind fromId(String id) => ModuleKind.values.firstWhere(
        (k) => k.name == id,
        orElse: () => ModuleKind.collector,
      );
}

/// What a kind IS, by where its content comes from — the desktop's
/// KIND_CATEGORY (DraconDex-EXE hub/kinds.js, DraconDex-APP docs/V5.md §9):
///   structure  holds modules, not content (collector)
///   view       shows other modules' content; deleting one loses only a
///              layout or a selection (manager, viewer, connector — the last
///              two become the desktop's exhibitor with APK V3)
///   data       owns content; deleting one deletes what was written in it
/// `required` below is the parity check: a 16th kind without a category is
/// a compile error, which the desktop gets from check.mjs instead.
enum ModuleCategory { structure, view, data }

class ModuleKindInfo {
  final ModuleKind kind;
  final ModuleCategory category;
  final String label;
  final IconData icon;
  final String description;
  /// Whether this kind has a real content editor on mobile yet. Kinds still
  /// pending get a generic placeholder + the shared description field.
  final bool contentImplemented;

  const ModuleKindInfo({
    required this.kind,
    required this.category,
    required this.label,
    required this.icon,
    required this.description,
    required this.contentImplemented,
  });
}

const Map<ModuleKind, ModuleKindInfo> moduleKindInfo = {
  ModuleKind.collector: ModuleKindInfo(
    kind: ModuleKind.collector,
    category: ModuleCategory.structure,
    label: 'Collector',
    icon: Icons.folder,
    description: 'Plain folder — groups children only',
    contentImplemented: true,
  ),
  ModuleKind.manager: ModuleKindInfo(
    kind: ModuleKind.manager,
    category: ModuleCategory.view,
    label: 'Manager',
    icon: Icons.dashboard_outlined,
    description: 'Container showing this module\'s children',
    contentImplemented: true,
  ),
  ModuleKind.inspector: ModuleKindInfo(
    kind: ModuleKind.inspector,
    category: ModuleCategory.data,
    label: 'Inspector',
    icon: Icons.description_outlined,
    description: 'A single note document',
    contentImplemented: true,
  ),
  ModuleKind.classifier: ModuleKindInfo(
    kind: ModuleKind.classifier,
    category: ModuleCategory.data,
    label: 'Classifier',
    icon: Icons.category_outlined,
    description: 'Category / object / field system',
    contentImplemented: true,
  ),
  ModuleKind.locator: ModuleKindInfo(
    kind: ModuleKind.locator,
    category: ModuleCategory.data,
    label: 'Locator',
    icon: Icons.map_outlined,
    description: 'Map canvas with drawable areas',
    contentImplemented: true,
  ),
  ModuleKind.chronicler: ModuleKindInfo(
    kind: ModuleKind.chronicler,
    category: ModuleCategory.data,
    label: 'Chronicler',
    icon: Icons.timeline_outlined,
    description: 'Timeline of dated events',
    contentImplemented: true,
  ),
  ModuleKind.wanderer: ModuleKindInfo(
    kind: ModuleKind.wanderer,
    category: ModuleCategory.data,
    label: 'Wanderer',
    icon: Icons.explore_outlined,
    description: 'Timeline events pinned on a map',
    contentImplemented: true,
  ),
  ModuleKind.narrator: ModuleKindInfo(
    kind: ModuleKind.narrator,
    category: ModuleCategory.data,
    label: 'Narrator',
    icon: Icons.forum_outlined,
    description: 'Dialogue graph / route board',
    contentImplemented: true,
  ),
  ModuleKind.author: ModuleKindInfo(
    kind: ModuleKind.author,
    category: ModuleCategory.data,
    label: 'Author',
    icon: Icons.menu_book_outlined,
    description: 'Book with chapters',
    contentImplemented: true,
  ),
  ModuleKind.scribe: ModuleKindInfo(
    kind: ModuleKind.scribe,
    category: ModuleCategory.data,
    label: 'Scribe',
    icon: Icons.chat_bubble_outline,
    description: 'Chat-style notes for this module',
    contentImplemented: true,
  ),
  ModuleKind.drafter: ModuleKindInfo(
    kind: ModuleKind.drafter,
    category: ModuleCategory.data,
    label: 'Drafter',
    icon: Icons.edit_note_outlined,
    description: 'A blank markdown page',
    contentImplemented: true,
  ),
  ModuleKind.viewer: ModuleKindInfo(
    kind: ModuleKind.viewer,
    category: ModuleCategory.view,
    label: 'Viewer',
    icon: Icons.visibility_outlined,
    description: 'Read-only saved-filter lens',
    contentImplemented: true,
  ),
  ModuleKind.connector: ModuleKindInfo(
    kind: ModuleKind.connector,
    category: ModuleCategory.view,
    label: 'Connector',
    icon: Icons.hub_outlined,
    description: 'Relationship graph over a saved filter',
    contentImplemented: true,
  ),
  ModuleKind.sketcher: ModuleKindInfo(
    kind: ModuleKind.sketcher,
    category: ModuleCategory.data,
    label: 'Sketcher',
    icon: Icons.brush_outlined,
    description: 'Freehand drawing canvas',
    contentImplemented: true,
  ),
  ModuleKind.designer: ModuleKindInfo(
    kind: ModuleKind.designer,
    category: ModuleCategory.data,
    label: 'Designer',
    icon: Icons.account_tree_outlined,
    description: 'Free-form diagram board',
    contentImplemented: true,
  ),
  ModuleKind.diviner: ModuleKindInfo(
    kind: ModuleKind.diviner,
    category: ModuleCategory.data,
    label: 'Diviner',
    icon: Icons.casino_outlined,
    description: 'Random tables and dice rolls',
    contentImplemented: false,
  ),
};

class ModuleModel {
  final int id;
  final int nexusRef;
  final int? parentId;
  final String name;
  final ModuleKind kind;
  final String? icon;
  final int? iconColorId;
  final String? iconColorCode;
  final int? colorId;
  final String? colorCode;
  final String? description;
  final int displayOrder;
  final bool pinned;
  final String createdAt;
  final String updatedAt;
  /// Present only on rows returned by a children query — number of modules
  /// nested directly under this one (drives the file-explorer folder look).
  final int? childCount;

  const ModuleModel({
    required this.id,
    required this.nexusRef,
    this.parentId,
    required this.name,
    required this.kind,
    this.icon,
    this.iconColorId,
    this.iconColorCode,
    this.colorId,
    this.colorCode,
    this.description,
    this.displayOrder = 0,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.childCount,
  });

  ModuleKindInfo get kindInfo => moduleKindInfo[kind]!;

  factory ModuleModel.fromMap(Map<String, dynamic> m) => ModuleModel(
        id: m['id'] as int,
        nexusRef: m['nexus_ref'] as int,
        parentId: m['parent_id'] as int?,
        name: m['name'] as String,
        kind: ModuleKind.fromId(m['kind'] as String),
        icon: m['icon'] as String?,
        iconColorId: m['icon_color'] as int?,
        iconColorCode: m['icon_color_code'] as String?,
        colorId: m['color'] as int?,
        colorCode: m['color_code'] as String?,
        description: m['description'] as String?,
        displayOrder: m['display_order'] as int? ?? 0,
        pinned: (m['pinned'] as int? ?? 0) != 0,
        createdAt: m['create_at'] as String? ?? '',
        updatedAt: m['update_at'] as String? ?? '',
        childCount: m['child_count'] as int?,
      );
}

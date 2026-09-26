import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import 'core_components.dart';
import 'kind_views.dart';
import 'media_components.dart';
import 'page_providers.dart';

/// What a component block is drawn with.
class ComponentCtx {
  final PageData page;
  final PageBlock block;

  /// The module whose data the component shows: the page's own module, or
  /// the one a borrowed block names in `source_key` (EXE page.js pbCtx).
  final ModuleModel source;

  /// The element page this block is on, null on a module page.
  final String? itemKey;

  /// Tablet-and-wider: canvases draw inline (V5.md §12.3 rules); a phone
  /// gets a thumbnail that opens full screen (APK-V3.md §4, §13 item 15).
  final bool wide;

  /// The preset this block shows (see [resolvePreset]); '' for a component
  /// without presets.
  final String preset;

  /// Drawn in the full-screen editor rather than on the page.
  final bool fullScreen;

  const ComponentCtx({
    required this.page,
    required this.block,
    required this.source,
    required this.itemKey,
    required this.wide,
    this.preset = '',
    this.fullScreen = false,
  });

  ComponentCtx copyWith({bool? fullScreen}) => ComponentCtx(
        page: page,
        block: block,
        source: source,
        itemKey: itemKey,
        wide: wide,
        preset: preset,
        fullScreen: fullScreen ?? this.fullScreen,
      );

  PageKey get key => PageKey(page.module.id, itemKey);
  int get nexusId => source.nexusRef;
  bool get borrowed => source.id != page.module.id;

}

/// The preset a block shows: its own, else the one the module was last left
/// on, else the component's first (EXE classifier.js:55).
String resolvePreset(ComponentDef def, PageBlock block, String? moduleView) {
  final own = block.preset;
  if (own != null && def.presets.contains(own)) return own;
  if (moduleView != null && def.presets.contains(moduleView)) return moduleView;
  return def.presets.isEmpty ? '' : def.presets.first;
}

/// A preset's name on screen.
String presetLabel(AppLocalizations l, String p) => switch (p) {
      'table' => l.viewTable,
      'listDetail' => l.viewListDetail,
      'relationCat' => l.viewRelations,
      'grid' => l.viewGrid,
      'scene' => l.viewScene,
      'graph' => l.viewGraph,
      'cards' => l.viewCards,
      'board' => l.viewBoard,
      'edges' => l.viewEdges,
      'area' => l.viewArea,
      'map' => l.viewMap,
      'timeline' => l.viewTimeline,
      'canvas' => l.viewCanvas,
      'pages' => l.viewPages,
      'gallery' => l.viewGallery,
      'export' => l.viewExport,
      'editor' => l.viewEditor,
      'outline' => l.viewOutline,
      'reading' => l.viewReading,
      'book' => l.viewBook,
      'routes' => l.viewRoutes,
      'reader' => l.viewReader,
      'dialogue' => l.viewDialogue,
      'oneline' => l.viewOneline,
      'downline' => l.viewDownline,
      'compare' => l.viewCompare,
      'calendar' => l.viewCalendar,
      'list' => l.viewList,
      'matrix' => l.viewMatrix,
      'chat' => l.viewChat,
      'transcript' => l.viewTranscript,
      _ => p,
    };

/// One registered component — the Flutter side of EXE registerComponent
/// (renderer/page/registry.js). Flags are the desktop's:
///   [once]    one per page (two live editors on one text would fight)
///   [borrow]  may be shown on another module's page, reading that module
///   [canvas]  draws a board/map: a thumbnail + full screen on a phone
class ComponentDef {
  final String id;
  final ModuleKind? kind;
  final List<String> presets;
  final bool once;
  final bool borrow;
  final bool canvas;

  /// With [canvas]: which presets are the canvas ones — empty means all.
  /// A Narrator's board is a canvas; its reader is text and stays inline.
  final Set<String> canvasPresets;
  final String Function(AppLocalizations l10n) label;
  final Widget Function(BuildContext context, ComponentCtx ctx) build;

  const ComponentDef({
    required this.id,
    required this.kind,
    required this.label,
    required this.build,
    this.presets = const [],
    this.once = false,
    this.borrow = false,
    this.canvas = false,
    this.canvasPresets = const {},
  });

  bool canvasFor(String preset) => canvas && (canvasPresets.isEmpty || canvasPresets.contains(preset));
}

String kindViewId(ModuleKind kind) => '${kind.id}.view';

/// Every component this app can draw, core first.
final Map<String, ComponentDef> components = {
  for (final def in [...coreComponents, ...mediaComponents, ...kindViewComponents]) def.id: def,
};

/// A module page's first layout (EXE registry.js defaultPageLayout): a
/// collector has none — it is its children — and every other kind gets
/// Properties, its own view on the preset it was last left on, and Related.
List<NewBlock> defaultPageLayout(ModuleKind kind, String? activeView) {
  if (kind == ModuleKind.collector) return const [];
  return [
    const NewBlock(component: 'core.properties'),
    NewBlock(component: kindViewId(kind), config: activeView == null || activeView.isEmpty ? null : {'preset': activeView}),
    const NewBlock(component: 'core.related'),
  ];
}

/// The layout every element page of a module shares until one is split off
/// (EXE item-page.js itemPageLayout).
List<NewBlock> itemPageLayout() => const [
      NewBlock(component: 'item.body'),
      NewBlock(component: 'core.properties'),
      NewBlock(component: 'core.related'),
    ];

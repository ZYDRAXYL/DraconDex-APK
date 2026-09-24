import 'package:flutter/material.dart';

import '../../data/models/module_model.dart';
import '../hub/content/designer_content.dart';
import '../hub/content/locator_content.dart';
import '../hub/content/scribe_content.dart';
import '../hub/content/sketcher_content.dart';
import '../hub/content/wanderer_content.dart';
import 'component_registry.dart';
import 'core_components.dart';
import 'views/author_views.dart';
import 'views/chronicler_views.dart';
import 'views/classifier_views.dart';
import 'views/narrator_views.dart';
import 'views/selection_views.dart';

/// `<kind>.view` for every kind that has a page, with the desktop's presets
/// (EXE renderer/mod/*.js registerComponent) — the 43 views of V5.md §12:
/// 39 across the ten kinds with presets, plus one each for diviner, locator,
/// drafter and inspector. Flags follow the desktop's: a canvas kind draws a
/// thumbnail on a phone (APK-V3.md §4), Wanderer cannot be borrowed.
final List<ComponentDef> kindViewComponents = [
  _view(ModuleKind.classifier, ['table', 'listDetail', 'relationCat', 'grid'],
      (c, x) => ClassifierView(ctx: x)),
  _view(ModuleKind.exhibitor, ['scene', 'graph', 'table', 'cards', 'board', 'edges'],
      (c, x) => SelectionView(ctx: x),
      canvas: true, canvasPresets: {'scene', 'graph'}),
  _view(ModuleKind.wanderer, ['area', 'map', 'timeline'],
      (c, x) => WandererContent(moduleId: x.source.id, nexusId: x.nexusId),
      canvas: true, canvasPresets: {'area', 'map'}, borrow: false),
  _view(ModuleKind.sketcher, ['canvas', 'pages', 'gallery', 'export'],
      (c, x) => SketcherContent(moduleId: x.source.id),
      canvas: true, canvasPresets: {'canvas'}),
  _view(ModuleKind.author, ['editor', 'board', 'outline', 'reading', 'book'],
      (c, x) => AuthorView(ctx: x)),
  _view(ModuleKind.narrator, ['board', 'routes', 'reader', 'dialogue'],
      (c, x) => NarratorView(ctx: x),
      canvas: true, canvasPresets: {'board'}),
  _view(ModuleKind.chronicler, ['oneline', 'downline', 'compare', 'calendar'],
      // Inline in every preset: a line scrolls sideways, a downline and a
      // calendar read top to bottom — none needs the full-screen frame.
      (c, x) => ChroniclerView(ctx: x)),
  // A Manager is a selection now (V5.md §8.9): the modules its filter picks.
  _view(ModuleKind.manager, ['cards', 'list', 'table', 'graph'], (c, x) => SelectionView(ctx: x)),
  _view(ModuleKind.designer, ['canvas', 'outline', 'matrix'],
      (c, x) => DesignerContent(moduleId: x.source.id),
      canvas: true, canvasPresets: {'canvas'}),
  _view(ModuleKind.scribe, ['chat', 'transcript'], (c, x) => ScribeContent(moduleId: x.source.id)),
  _view(ModuleKind.diviner, const [], (c, x) => NotYetOnMobile(label: x.source.kindInfo.label)),
  _view(ModuleKind.locator, const [], (c, x) => LocatorContent(moduleId: x.source.id), canvas: true),
  // The module's description IS the document for these two, so each is
  // `once` — two live editors on one text would overwrite each other.
  _view(ModuleKind.drafter, const [], (c, x) => DescriptionDocument(module: x.source, tall: true), once: true),
  _view(ModuleKind.inspector, const [], (c, x) => DescriptionDocument(module: x.source), once: true),
];

ComponentDef _view(
  ModuleKind kind,
  List<String> presets,
  Widget Function(BuildContext context, ComponentCtx ctx) build, {
  bool canvas = false,
  Set<String> canvasPresets = const {},
  bool borrow = true,
  bool once = false,
}) =>
    ComponentDef(
      id: kindViewId(kind),
      kind: kind,
      presets: presets,
      canvas: canvas,
      canvasPresets: canvasPresets,
      borrow: borrow,
      once: once,
      label: (_) => moduleKindInfo[kind]!.label,
      build: build,
    );

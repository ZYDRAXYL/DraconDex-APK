import 'package:flutter/material.dart';

import '../../data/models/module_model.dart';
import '../hub/content/author_content.dart';
import '../hub/content/chronicler_content.dart';
import '../hub/content/classifier_content.dart';
import '../hub/content/designer_content.dart';
import '../hub/content/locator_content.dart';
import '../hub/content/narrator_content.dart';
import '../hub/content/scribe_content.dart';
import '../hub/content/sketcher_content.dart';
import '../hub/content/viewer_content.dart';
import '../hub/content/wanderer_content.dart';
import 'component_registry.dart';
import 'core_components.dart';

/// `<kind>.view` for every kind that has a page, with the desktop's presets
/// (EXE renderer/mod/*.js registerComponent) — the 43 views of V5.md §12:
/// 39 across the ten kinds with presets, plus one each for diviner, locator,
/// drafter and inspector. Flags follow the desktop's: a canvas kind draws a
/// thumbnail on a phone (APK-V3.md §4), Wanderer cannot be borrowed.
final List<ComponentDef> kindViewComponents = [
  _view(ModuleKind.classifier, ['table', 'listDetail', 'relationCat', 'grid'],
      (c, x) => ClassifierContent(moduleId: x.source.id)),
  _view(ModuleKind.exhibitor, ['scene', 'graph', 'table', 'cards', 'board', 'edges'],
      (c, x) => ViewerContent(moduleId: x.source.id, nexusId: x.nexusId),
      canvas: true),
  _view(ModuleKind.wanderer, ['area', 'map', 'timeline'],
      (c, x) => WandererContent(moduleId: x.source.id, nexusId: x.nexusId),
      canvas: true, borrow: false),
  _view(ModuleKind.sketcher, ['canvas', 'pages', 'gallery', 'export'],
      (c, x) => SketcherContent(moduleId: x.source.id),
      canvas: true),
  _view(ModuleKind.author, ['editor', 'board', 'outline', 'reading', 'book'],
      (c, x) => AuthorContent(moduleId: x.source.id)),
  _view(ModuleKind.narrator, ['board', 'routes', 'reader', 'dialogue'],
      (c, x) => NarratorContent(moduleId: x.source.id),
      canvas: true),
  _view(ModuleKind.chronicler, ['oneline', 'downline', 'compare', 'calendar'],
      (c, x) => ChroniclerContent(moduleId: x.source.id),
      canvas: true),
  // A Manager is a selection now (V5.md §8.9): the modules its filter picks.
  _view(ModuleKind.manager, ['cards', 'list', 'table', 'graph'],
      (c, x) => ViewerContent(moduleId: x.source.id, nexusId: x.nexusId)),
  _view(ModuleKind.designer, ['canvas', 'outline', 'matrix'],
      (c, x) => DesignerContent(moduleId: x.source.id),
      canvas: true),
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
  bool borrow = true,
  bool once = false,
}) =>
    ComponentDef(
      id: kindViewId(kind),
      kind: kind,
      presets: presets,
      canvas: canvas,
      borrow: borrow,
      once: once,
      label: (_) => moduleKindInfo[kind]!.label,
      build: build,
    );

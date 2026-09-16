import 'package:flutter/material.dart';
import '../../../data/models/module_model.dart';
import 'author_content.dart';
import 'chronicler_content.dart';
import 'scribe_content.dart';

/// Maps a module kind to its content editor.
///
/// Before this existed, every non-folder kind rendered the same shared notes
/// field, and the ones without a real editor said so in red
/// (`kindContentUnavailable`). Kinds are ported one at a time: a kind gets an
/// arm here *and* is flipped to `contentImplemented: true` in [moduleKindInfo]
/// in the same change, so the registry flag and what the screen actually
/// renders can never disagree.
///
/// Returns null when the kind has no dedicated editor yet — the caller falls
/// back to the notes field and keeps showing the warning. Every kind is listed
/// rather than covered by a wildcard so that adding a 16th kind is a compile
/// error here instead of a silent fall-through to the notes field.
Widget? moduleContentFor(ModuleModel module) => switch (module.kind) {
      ModuleKind.author => AuthorContent(moduleId: module.id),
      ModuleKind.scribe => ScribeContent(moduleId: module.id),
      ModuleKind.chronicler => ChroniclerContent(moduleId: module.id),
      // Folders have no content area at all; the caller returns early.
      ModuleKind.collector || ModuleKind.manager => null,
      // The notes field genuinely is the content for these two.
      ModuleKind.inspector || ModuleKind.drafter => null,
      // Still pending a dedicated editor.
      ModuleKind.classifier ||
      ModuleKind.locator ||
      ModuleKind.wanderer ||
      ModuleKind.narrator ||
      ModuleKind.viewer ||
      ModuleKind.connector ||
      ModuleKind.sketcher ||
      ModuleKind.designer =>
        null,
    };

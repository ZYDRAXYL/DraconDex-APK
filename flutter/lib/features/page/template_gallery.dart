import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/models/module_model.dart';
import '../../data/services/page_template_service.dart';
import '../../providers/db_providers.dart';
import 'page_providers.dart';

/// A new module's first page: its kind's ★ template (the desktop's
/// applyStartTemplate). A failure leaves the default layout, which the page
/// makes on first open anyway.
Future<void> applyStartTemplate(Database db, int moduleId, ModuleKind kind, String locale) async {
  try {
    final tpl = await PageTemplateService.defaultFor(kind.id, locale);
    if (tpl != null) await PageTemplateService.apply(db, moduleId, tpl);
  } catch (_) {}
}

/// "Use template…" from the page's ⋮ (APP docs/TEMPLATES.md §3.3): this
/// kind's templates, ★ first; picking one replaces the page's layout —
/// content stays — with Undo right after.
Future<void> showTemplateGallery(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final list = await PageTemplateService.templates(locale, kind: module.kind.id);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final tpl = await showModalBottomSheet<PageTemplate>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(s).height * .8),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(l10n.tplUse.replaceAll('…', ''), style: Theme.of(s).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.tplUseHint, style: TextStyle(fontSize: 12, color: s.ddx.textMuted)),
          ),
          for (final t in list)
            ListTile(
              leading: Icon(t.isDefault ? Icons.star : Icons.dashboard_outlined, color: t.isDefault ? Colors.amber : null),
              title: Text(t.name),
              subtitle: Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: t.isDefault ? Text(l10n.tplDefault, style: TextStyle(fontSize: 12, color: s.ddx.textMuted)) : null,
              onTap: () => Navigator.pop(s, t),
            ),
        ]),
      ),
    ),
  );
  if (tpl == null) return;
  final db = await ref.read(databaseProvider.future);
  final key = PageKey(module.id, null);
  final r = await PageTemplateService.apply(db, module.id, tpl);
  ref.invalidate(pageProvider(key));
  ref.invalidate(pageProvider(PageKey(module.id, '*')));
  if (r.dropped > 0) messenger.showSnackBar(SnackBar(content: Text(l10n.tplBorrowDropped.replaceAll('{n}', '${r.dropped}'))));
  messenger.showSnackBar(SnackBar(
    content: Text(l10n.tplApplied),
    action: SnackBarAction(
      label: l10n.btnUndo,
      onPressed: () async {
        await PageTemplateService.restore(db, module.id, r.old);
        ref.invalidate(pageProvider(key));
      },
    ),
  ));
}

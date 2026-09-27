import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/models/module_model.dart';
import '../../data/services/page_template_service.dart';
import '../../data/services/preset_service.dart';
import '../../widgets/confirm_dialog.dart';
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
/// kind's templates, ★ first, then the user's own ("Mine"); picking one
/// replaces the page's layout — content stays — with Undo right after. A
/// long press on one of Mine deletes it.
Future<void> showTemplateGallery(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final list = await PageTemplateService.templates(locale, kind: module.kind.id);
  final db0 = await ref.read(databaseProvider.future);
  final mine = await PresetService.mine(db0, module.nexusRef, module.kind.id);
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
          if (mine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(l10n.tplMine, style: Theme.of(s).textTheme.labelLarge?.copyWith(color: Theme.of(s).colorScheme.primary)),
            ),
          for (final t in mine)
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(t.name),
              trailing: Text(l10n.tplMine, style: TextStyle(fontSize: 12, color: s.ddx.textMuted)),
              onTap: () => Navigator.pop(s, t),
              onLongPress: () async {
                if (!await showConfirmDialog(s, message: l10n.presetDeleteConfirm)) return;
                await PresetService.delete(db0, int.parse(t.id.substring(2)));
                if (s.mounted) Navigator.pop(s);
              },
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

/// "Save page as template…" from the page's ⋮ — the module's look, view,
/// fields and page (not its content), kept in this vault as one of Mine.
Future<void> showSaveTemplateDialog(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final c = TextEditingController(text: module.name);
  final name = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l10n.tplSave.replaceAll('…', '')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.nameField),
          onSubmitted: (v) => Navigator.pop(d, v.trim()),
        ),
        const SizedBox(height: 10),
        Text(l10n.savePresetHint, style: TextStyle(fontSize: 12, color: d.ddx.textMuted)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l10n.btnSave)),
      ],
    ),
  );
  c.dispose();
  if (name == null) return;
  if (name.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.nameRequired)));
    return;
  }
  final db = await ref.read(databaseProvider.future);
  await PresetService.save(db, module.nexusRef, module.id, name);
  messenger.showSnackBar(SnackBar(content: Text(l10n.presetSaved)));
}

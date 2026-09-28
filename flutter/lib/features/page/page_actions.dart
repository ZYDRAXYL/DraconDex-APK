import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import '../../widgets/row_menu.dart';
import 'page_header.dart';
import 'page_providers.dart';
import 'template_gallery.dart';

/// The page's own entries in the screen's ⋮ (the "page" section, UX-LAYOUT
/// §7.2): title layout, templates, and on an element page, split it off the
/// shared layout or go back to it (V5.md §12.5). Arrange is the FAB.
List<RowAction> pageActions(BuildContext context, WidgetRef ref, ModuleModel module, String? itemKey) {
  final l10n = AppLocalizations.of(context)!;
  if (itemKey == null && module.kind == ModuleKind.collector) return const [];
  final key = PageKey(module.id, itemKey);
  final from = ref.read(pageProvider(key)).valueOrNull?.from;
  return [
    // The title's own layout, per page (APP docs/REDESIGN.md C6).
    RowAction(
      label: l10n.pageLayout,
        group: RowGroup.page,
      icon: Icons.format_align_center,
      onTap: () => showPageLayoutSheet(context, ref, module, itemKey),
    ),
    if (itemKey == null)
      RowAction(
        label: l10n.tplUse,
        group: RowGroup.page,
        icon: Icons.dashboard_outlined,
        onTap: () => showTemplateGallery(context, ref, module),
      ),
    if (itemKey == null)
      RowAction(
        label: l10n.tplSave,
        group: RowGroup.page,
        icon: Icons.bookmark_add_outlined,
        onTap: () => showSaveTemplateDialog(context, ref, module),
      ),
    // Arrange is the page's FAB now ("Edit page", UX-LAYOUT §7.1), not a row here.
    if (itemKey != null && from == PageSource.shared)
      RowAction(
        label: l10n.pbSplit,
        group: RowGroup.page,
        icon: Icons.call_split,
        onTap: () async {
          final dao = await ref.read(pageBlockDaoProvider.future);
          await dao.split(module.id, itemKey);
          ref.invalidate(pageProvider(key));
        },
      ),
    if (itemKey != null && from == PageSource.own)
      RowAction(
        label: l10n.pbRevert,
        group: RowGroup.page,
        icon: Icons.merge_type,
        onTap: () async {
          final dao = await ref.read(pageBlockDaoProvider.future);
          await dao.revert(module.id, itemKey);
          ref.invalidate(pageProvider(key));
        },
      ),
  ];
}

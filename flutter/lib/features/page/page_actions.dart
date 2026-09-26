import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import '../../widgets/row_menu.dart';
import 'page_header.dart';
import 'page_providers.dart';

/// The page's own entries in the screen's ⋮: arrange it, and on an element
/// page, split it off the shared layout or go back to it (V5.md §12.5).
List<RowAction> pageActions(BuildContext context, WidgetRef ref, ModuleModel module, String? itemKey) {
  final l10n = AppLocalizations.of(context)!;
  if (itemKey == null && module.kind == ModuleKind.collector) return const [];
  final key = PageKey(module.id, itemKey);
  final from = ref.read(pageProvider(key)).valueOrNull?.from;
  return [
    // The title's own layout, per page (APP docs/REDESIGN.md C6).
    RowAction(
      label: l10n.pageLayout,
      icon: Icons.format_align_center,
      onTap: () => showPageLayoutSheet(context, ref, module, itemKey),
    ),
    RowAction(
      label: l10n.pbArrange,
      icon: Icons.dashboard_customize_outlined,
      onTap: () => ref.read(arrangeModeProvider(key).notifier).state = !ref.read(arrangeModeProvider(key)),
    ),
    if (itemKey != null && from == PageSource.shared)
      RowAction(
        label: l10n.pbSplit,
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
        icon: Icons.merge_type,
        onTap: () async {
          final dao = await ref.read(pageBlockDaoProvider.future);
          await dao.revert(module.id, itemKey);
          ref.invalidate(pageProvider(key));
        },
      ),
  ];
}

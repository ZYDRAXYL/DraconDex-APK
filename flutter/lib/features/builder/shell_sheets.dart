import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../widgets/row_menu.dart';

/// The Navibar's "Tools" slot (APP docs/APK-V3.md §10.1): the vault-wide
/// tools. Colours today; CSV import and Problems join it with Procress 12
/// part 2.
List<RowAction> toolsActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final router = GoRouter.of(context);
  return [
    RowAction(label: l10n.moduleColors, icon: Icons.palette_outlined, onTap: () => router.push('/colors')),
  ];
}

/// The Navibar's "More" slot: what does not earn a slot of its own. Labels
/// and Settings today; Insight and the trash join it with part 2.
List<RowAction> moreActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final router = GoRouter.of(context);
  return [
    RowAction(label: l10n.moduleGlobalTags, icon: Icons.sell_outlined, onTap: () => router.push('/tags')),
    RowAction(label: l10n.moduleSettings, icon: Icons.settings_outlined, onTap: () => router.push('/settings')),
  ];
}

Future<void> showToolsSheet(BuildContext context) =>
    showRowMenu(context, toolsActions(context), title: AppLocalizations.of(context)!.navTools);

Future<void> showMoreSheet(BuildContext context) =>
    showRowMenu(context, moreActions(context), title: AppLocalizations.of(context)!.navMore);

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../widgets/row_menu.dart';

/// The Nexus the app is in (from the location), or null on the Nexus list.
int? currentNexusId(BuildContext context) {
  final path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  final m = RegExp(r'^/hub/(\d+)').firstMatch(path);
  return m == null ? null : int.parse(m[1]!);
}

/// The Navibar's "Tools" slot (APP docs/APK-V3.md §10.1): the vault-wide
/// tools — colours, and inside a Nexus its assets, its problems and a CSV
/// import.
List<RowAction> toolsActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final router = GoRouter.of(context);
  final nx = currentNexusId(context);
  return [
    if (nx != null) ...[
      RowAction(label: l10n.assetsTitle, icon: Icons.perm_media_outlined, onTap: () => router.push('/assets/$nx')),
      RowAction(label: l10n.problemsTitle, icon: Icons.rule_outlined, onTap: () => router.push('/problems/$nx')),
      RowAction(label: l10n.csvImportTitle, icon: Icons.table_view_outlined, onTap: () => router.push('/csv/$nx')),
    ],
    RowAction(label: l10n.moduleColors, icon: Icons.palette_outlined, onTap: () => router.push('/colors')),
  ];
}

/// The Navibar's "More" slot: what does not earn a slot of its own — the
/// Nexus's Trash, labels, the guide and Settings.
List<RowAction> moreActions(BuildContext context, {void Function(int nexusId)? onAddGuide}) {
  final l10n = AppLocalizations.of(context)!;
  final router = GoRouter.of(context);
  final nx = currentNexusId(context);
  return [
    if (nx != null) RowAction(label: l10n.trashTitle, icon: Icons.delete_outline, onTap: () => router.push('/trash/$nx')),
    if (nx != null && onAddGuide != null) RowAction(label: l10n.guideAdd, icon: Icons.school_outlined, onTap: () => onAddGuide(nx)),
    RowAction(label: l10n.moduleGlobalTags, icon: Icons.sell_outlined, onTap: () => router.push('/tags')),
    RowAction(label: l10n.moduleSettings, icon: Icons.settings_outlined, onTap: () => router.push('/settings')),
  ];
}

Future<void> showToolsSheet(BuildContext context) =>
    showRowMenu(context, toolsActions(context), title: AppLocalizations.of(context)!.navTools);

Future<void> showMoreSheet(BuildContext context, {void Function(int nexusId)? onAddGuide}) =>
    showRowMenu(context, moreActions(context, onAddGuide: onAddGuide), title: AppLocalizations.of(context)!.navMore);

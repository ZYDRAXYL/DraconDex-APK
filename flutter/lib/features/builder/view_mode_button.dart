import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../providers/builder_view_provider.dart';

/// How a page lays out the rows under it — list, grid, compact — as an app
/// bar action on the page itself. It was a Navibar slot and a rail button
/// before APK V3; a choice about a page belongs on the page's header (APP
/// docs/APK-V3.md §10.1), and the Navibar's five slots are for going places.
class ViewModeButton extends ConsumerWidget {
  const ViewModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(builderViewModeProvider);

    String labelFor(BuilderViewMode mode) => switch (mode) {
          BuilderViewMode.list => l10n.viewModeList,
          BuilderViewMode.grid => l10n.viewModeGrid,
          BuilderViewMode.compact => l10n.viewModeCompact,
        };

    return PopupMenuButton<BuilderViewMode>(
      icon: Icon(current.icon),
      tooltip: l10n.viewModeTitle,
      position: PopupMenuPosition.under,
      onSelected: (mode) => ref.read(builderViewModeProvider.notifier).set(mode),
      itemBuilder: (_) => [
        for (final mode in BuilderViewMode.values)
          PopupMenuItem<BuilderViewMode>(
            value: mode,
            child: Row(
              children: [
                Icon(mode.icon, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(labelFor(mode))),
                if (mode == current) const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

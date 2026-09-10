import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../providers/builder_view_provider.dart';

/// The Navibar's "view" button: pick how collections are laid out.
Future<void> showViewModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ViewModeSheet(),
  );
}

class _ViewModeSheet extends ConsumerWidget {
  const _ViewModeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(builderViewModeProvider);

    String labelFor(BuilderViewMode mode) => switch (mode) {
          BuilderViewMode.list => l10n.viewModeList,
          BuilderViewMode.grid => l10n.viewModeGrid,
          BuilderViewMode.compact => l10n.viewModeCompact,
        };

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.viewModeTitle, style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioGroup<BuilderViewMode>(
            groupValue: current,
            onChanged: (picked) async {
              if (picked == null) return;
              await ref.read(builderViewModeProvider.notifier).set(picked);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Column(
              children: [
                for (final mode in BuilderViewMode.values)
                  RadioListTile<BuilderViewMode>(
                    value: mode,
                    secondary: Icon(mode.icon),
                    title: Text(labelFor(mode)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

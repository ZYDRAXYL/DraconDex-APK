import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/viewer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import 'filter_editor.dart';

/// Viewer kind: a read-only lens over a saved filter.
///
/// The filter persists in module_ui['filterDef'] and is re-evaluated against
/// the whole-Nexus index on every open, so edits to the source data show up
/// here without touching the Viewer. Nothing in this screen writes to the
/// items it lists — only the filter itself is authored.
class ViewerContent extends ConsumerWidget {
  final int moduleId;
  final int nexusId;

  const ViewerContent({super.key, required this.moduleId, required this.nexusId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final indexAsync = ref.watch(viewerIndexProvider(nexusId));
    final defAsync = ref.watch(filterDefProvider(moduleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.viewerResults, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final items = indexAsync.valueOrNull ?? const <IndexedItem>[];
                  final edited = await showFilterEditor(
                    context,
                    initial: defAsync.valueOrNull ?? const FilterDef(),
                    modules: items.where((i) => i.itemKind == 'module').toList(),
                  );
                  if (edited == null) return;
                  final dao = ref.read(viewerDaoProvider).valueOrNull;
                  await dao?.setFilterDef(moduleId, edited);
                  ref.invalidate(filterDefProvider(moduleId));
                },
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(l10n.filterTitle),
              ),
            ],
          ),
          _results(context, ref, indexAsync, defAsync, l10n, theme),
        ],
      ),
    );
  }

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<IndexedItem>> indexAsync,
    AsyncValue<FilterDef> defAsync,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (indexAsync.isLoading || defAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = indexAsync.error ?? defAsync.error;
    if (error != null) {
      return Text('$error', style: TextStyle(color: theme.colorScheme.error));
    }

    final def = defAsync.valueOrNull ?? const FilterDef();
    if (def.isEmpty) {
      // An unconfigured lens says so rather than dumping the whole vault.
      return Text(l10n.viewerNoFilter, style: theme.textTheme.bodySmall);
    }

    final results = applyFilter(
        indexAsync.valueOrNull ?? const <IndexedItem>[], def, moduleId);
    if (results.isEmpty) {
      return Text(l10n.viewerNoResults, style: theme.textTheme.bodySmall);
    }

    return Column(
      children: [
        for (final it in results)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_iconFor(it.itemKind), size: 18),
            title: Text(
              it.name.isEmpty ? l10n.viewerUntitled : it.name,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(it.moduleName, style: theme.textTheme.bodySmall),
            trailing: Text(it.itemKind, style: theme.textTheme.labelSmall),
          ),
      ],
    );
  }

  IconData _iconFor(String itemKind) => switch (itemKind) {
        'module' => Icons.folder_outlined,
        'object' => Icons.category_outlined,
        'event' => Icons.timeline_outlined,
        'dialogue' => Icons.forum_outlined,
        'chapter' => Icons.menu_book_outlined,
        'chat' => Icons.chat_bubble_outline,
        _ => Icons.description_outlined,
      };
}

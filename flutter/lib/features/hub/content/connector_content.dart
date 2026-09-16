import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/viewer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import 'filter_editor.dart';

/// Connector kind: the saved filter's relation graph.
///
/// It shares the Viewer's index, filter shape and filter editor — the same
/// pairing the desktop has between mod/connector.js and mod/viewer.js. The
/// filtered items are the nodes; the edges are this Nexus's entity_relation
/// rows whose endpoints both survive the filter.
///
/// The desktop offers a graph view and an edge list. This renders the edge
/// list: a force-directed graph is the wrong thing to pan and pinch on a
/// phone, and the edge list carries the same information without pretending
/// otherwise. The items themselves stay read-only here — only the relations
/// are authored, exactly as upstream.
class ConnectorContent extends ConsumerWidget {
  final int moduleId;
  final int nexusId;

  const ConnectorContent({super.key, required this.moduleId, required this.nexusId});

  Future<void> _addRelation(
    BuildContext context,
    WidgetRef ref,
    List<IndexedItem> nodes,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (nodes.length < 2) return;

    String? fromKey;
    String? toKey;
    final label = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.connectorAddRelation),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: fromKey,
                  isExpanded: true,
                  hint: Text(l10n.connectorFrom),
                  items: [
                    for (final n in nodes)
                      DropdownMenuItem(
                        value: n.key,
                        child: Text(
                          n.name.isEmpty ? l10n.viewerUntitled : n.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => fromKey = v),
                ),
                DropdownButton<String>(
                  value: toKey,
                  isExpanded: true,
                  hint: Text(l10n.connectorTo),
                  items: [
                    for (final n in nodes)
                      DropdownMenuItem(
                        value: n.key,
                        child: Text(
                          n.name.isEmpty ? l10n.viewerUntitled : n.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => toKey = v),
                ),
                TextField(
                  controller: label,
                  decoration: InputDecoration(labelText: l10n.connectorLabel),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.btnCancel)),
            FilledButton(
              // A self-edge is not a relation; require two distinct endpoints.
              onPressed: (fromKey == null || toKey == null || fromKey == toKey)
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: Text(l10n.btnSave),
            ),
          ],
        ),
      ),
    );
    if (ok != true || fromKey == null || toKey == null) return;

    final dao = ref.read(viewerDaoProvider).valueOrNull;
    await dao?.addRelation(
      nexusId: nexusId,
      fromKey: fromKey!,
      toKey: toKey!,
      label: label.text.trim().isEmpty ? null : label.text.trim(),
    );
    ref.invalidate(relationsProvider(nexusId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final indexAsync = ref.watch(viewerIndexProvider(nexusId));
    final defAsync = ref.watch(filterDefProvider(moduleId));
    final relsAsync = ref.watch(relationsProvider(nexusId));

    if (indexAsync.isLoading || defAsync.isLoading || relsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = indexAsync.error ?? defAsync.error ?? relsAsync.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$error', style: TextStyle(color: theme.colorScheme.error)),
      );
    }

    final index = indexAsync.valueOrNull ?? const <IndexedItem>[];
    final def = defAsync.valueOrNull ?? const FilterDef();
    final nodes = applyFilter(index, def, moduleId);
    final byKey = {for (final n in nodes) n.key: n};

    // Only edges whose BOTH endpoints survived the filter, matching the
    // desktop's loadConnectorData.
    final edges = (relsAsync.valueOrNull ?? const <Map<String, Object?>>[])
        .where((r) =>
            byKey.containsKey(r['from_key'] as String? ?? '') &&
            byKey.containsKey(r['to_key'] as String? ?? ''))
        .toList();

    String nameOf(String? key) {
      final n = byKey[key ?? ''];
      if (n == null) return '';
      return n.name.isEmpty ? l10n.viewerUntitled : n.name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.connectorRelations, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final edited = await showFilterEditor(
                    context,
                    initial: def,
                    modules: index.where((i) => i.itemKind == 'module').toList(),
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
          if (def.isEmpty)
            Text(l10n.viewerNoFilter, style: theme.textTheme.bodySmall)
          else ...[
            Row(
              children: [
                Text('${l10n.connectorNodes}: ${nodes.length}',
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                TextButton.icon(
                  onPressed:
                      nodes.length < 2 ? null : () => _addRelation(context, ref, nodes),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.connectorAddRelation),
                ),
              ],
            ),
            if (edges.isEmpty)
              Text(l10n.connectorNoRelations, style: theme.textTheme.bodySmall)
            else
              Column(
                children: [
                  for (final e in edges)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${nameOf(e['from_key'] as String?)}  →  ${nameOf(e['to_key'] as String?)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: (e['label'] as String?)?.isNotEmpty == true
                          ? Text(e['label'] as String,
                              style: theme.textTheme.bodySmall)
                          : null,
                      trailing: IconButton(
                        tooltip: l10n.btnDelete,
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: l10n.confirmDeleteTitle,
                            message: l10n.confirmDeleteMessage,
                          );
                          if (!confirmed) return;
                          final dao = ref.read(viewerDaoProvider).valueOrNull;
                          await dao?.deleteRelation(e['id'] as int);
                          ref.invalidate(relationsProvider(nexusId));
                        },
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

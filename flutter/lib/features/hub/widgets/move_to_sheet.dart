import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../page/views/view_common.dart';

/// Where a move lands: a Collector, or the top level ([parentId] null —
/// for an asset that is the unfiled tray).
typedef MoveTarget = ({int? parentId, String name});

/// "Move to…" — pick a folder the way a file manager's Move does (and the
/// way Unity's Project window reads): drill down through the Collectors of
/// this Nexus from the top level, make a new folder where you stand if the
/// one you want does not exist yet, then "Move here". Only Collectors are
/// listed — only a Collector holds anything (V5.md §8.8) — and the modules
/// being moved ([moving]) are shown but closed, so nothing can be moved into
/// itself or its own subtree.
///
/// Null when dismissed.
Future<MoveTarget?> showMoveToSheet(
  BuildContext context, {
  required int nexusId,
  Set<int> moving = const {},
  int? startAt,
}) {
  return showModalBottomSheet<MoveTarget>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MoveToSheet(nexusId: nexusId, moving: moving, startAt: startAt),
  );
}

class _MoveToSheet extends ConsumerStatefulWidget {
  final int nexusId;
  final Set<int> moving;
  final int? startAt;
  const _MoveToSheet({required this.nexusId, required this.moving, this.startAt});

  @override
  ConsumerState<_MoveToSheet> createState() => _MoveToSheetState();
}

class _MoveToSheetState extends ConsumerState<_MoveToSheet> {
  /// The folders from the top level down to where the picker stands.
  final List<ModuleModel> _path = [];

  int? get _here => _path.isEmpty ? null : _path.last.id;

  @override
  void initState() {
    super.initState();
    _openAt(widget.startAt);
  }

  /// Starts inside the folder the moved things are in now — the move most
  /// people make is to a sibling or a child of where they already are.
  Future<void> _openAt(int? id) async {
    if (id == null || widget.moving.contains(id)) return;
    final dao = ref.read(moduleDaoProvider).valueOrNull;
    if (dao == null) return;
    final m = await dao.getModule(id);
    if (m == null || m.kind != ModuleKind.collector) return;
    final chain = await dao.getAncestors(id);
    if (chain.any((a) => widget.moving.contains(a.id))) return;
    if (mounted) setState(() => _path..clear()..addAll([...chain, m]));
  }

  Future<void> _newFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await askText(context, l10n.moveNewFolder, label: l10n.labelName);
    if (name == null || name.trim().isEmpty) return;
    final dao = ref.read(moduleDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createModule(nexusRef: widget.nexusId, parentId: _here, name: name.trim(), kind: ModuleKind.collector);
    ref.invalidate(moduleChildrenProvider(ModuleChildrenKey(widget.nexusId, _here)));
    ref.invalidate(nexusIndexProvider(widget.nexusId));
    final m = await dao.getModule(id);
    if (m != null && mounted) setState(() => _path.add(m));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nexus = ref.watch(nexusProvider(widget.nexusId)).valueOrNull;
    final children = ref.watch(moduleChildrenProvider(ModuleChildrenKey(widget.nexusId, _here)));
    final hereName = _path.isEmpty ? (nexus?.name ?? l10n.moveToRoot) : _path.last.name;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l10n.moveTo, style: theme.textTheme.titleMedium),
            ),
            // Where the picker stands, as tappable crumbs back up.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                TextButton.icon(
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: Text(nexus?.name ?? l10n.moveToRoot),
                  onPressed: _path.isEmpty ? null : () => setState(_path.clear),
                ),
                for (var i = 0; i < _path.length; i++) ...[
                  const Icon(Icons.chevron_right, size: 18),
                  TextButton(
                    onPressed: i == _path.length - 1 ? null : () => setState(() => _path.removeRange(i + 1, _path.length)),
                    child: Text(_path[i].name),
                  ),
                ],
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: children.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  final folders = [for (final m in list) if (m.kind == ModuleKind.collector) m];
                  return ListView(children: [
                    for (final f in folders)
                      ListTile(
                        enabled: !widget.moving.contains(f.id),
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() => _path.add(f)),
                      ),
                    ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: Text(l10n.moveNewFolder),
                      onTap: _newFolder,
                    ),
                  ]);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Expanded(
                  child: Text(hereName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: Text(l10n.moveHere),
                  onPressed: () => Navigator.pop<MoveTarget>(context, (parentId: _here, name: hereName)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

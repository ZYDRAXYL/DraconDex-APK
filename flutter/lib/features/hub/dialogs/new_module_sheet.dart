import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/module_dao.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/recent_view_model.dart';
import '../../../data/services/bundle_service.dart';
import '../../../data/services/mddx.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../page/views/view_common.dart';

/// The kind picker's groups (V5.md §9.5, EXE hub/kinds.js KIND_GROUPS):
/// structure · view · data, and five sub-groups under data.
const kindGroups = <(ModuleCategory, String?, List<ModuleKind>)>[
  (ModuleCategory.structure, null, [ModuleKind.collector]),
  (ModuleCategory.view, null, [ModuleKind.manager, ModuleKind.exhibitor]),
  (ModuleCategory.data, 'notes', [ModuleKind.inspector, ModuleKind.drafter]),
  (ModuleCategory.data, 'data', [ModuleKind.classifier, ModuleKind.diviner]),
  (ModuleCategory.data, 'mapTime', [ModuleKind.locator, ModuleKind.chronicler, ModuleKind.wanderer]),
  (ModuleCategory.data, 'story', [ModuleKind.narrator, ModuleKind.author, ModuleKind.scribe]),
  (ModuleCategory.data, 'draw', [ModuleKind.sketcher, ModuleKind.designer]),
];

void refreshTree(WidgetRef ref, int nexusId) {
  ref.invalidate(moduleChildrenProvider);
  ref.invalidate(nexusIndexProvider(nexusId));
  ref.invalidate(pinnedModulesProvider(nexusId));
}

/// Builds a template ([spec] from the genre bundles or the guide) under
/// [parentId] and opens what it made.
Future<void> createFromTemplate(BuildContext context, WidgetRef ref, int nexusId, int? parentId, Map<String, dynamic> spec) async {
  final router = GoRouter.of(context);
  final db = await ref.read(databaseProvider.future);
  final r = await BundleService.create(db, nexusId, parentId, spec);
  refreshTree(ref, nexusId);
  final open = r.managerId ?? r.folderId ?? (r.moduleIds.isEmpty ? null : r.moduleIds.first);
  if (open != null) router.push(RecentView.locationFor(nexusId, open));
}

/// The genre bundles and the guide, in the UI language (SDB templates/).
Future<Map<String, dynamic>?> pickTemplate(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final bundles = await BundleService.loadBundles(locale);
  if (!context.mounted) return null;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(l.fromTemplate, style: Theme.of(s).textTheme.titleMedium),
        ),
        for (final b in bundles)
          ListTile(
            leading: const Icon(Icons.auto_awesome_mosaic_outlined),
            title: Text('${b['name']}'),
            subtitle: Text('${b['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(s, <String, dynamic>{...(b['spec'] as Map<String, dynamic>), 'name': b['name'], 'icon': b['icon']}),
          ),
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(l.guideTitle),
          subtitle: Text(l.guideDesc),
          onTap: () async {
            final spec = await BundleService.loadGuide(locale);
            if (s.mounted) Navigator.pop(s, spec);
          },
        ),
      ]),
    ),
  );
}

/// "New" in a Nexus or a folder (APK-V3.md §7): a searchable, grouped kind
/// list, with a template, a .mddx file or a CSV above it.
Future<void> showNewModuleSheet(BuildContext context, WidgetRef ref, int nexusId, int? parentId) async {
  final router = GoRouter.of(context);
  final picked = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => const _KindSheet(),
  );
  if (picked == null || !context.mounted) return;
  final l = AppLocalizations.of(context)!;
  final db = await ref.read(databaseProvider.future);
  switch (picked) {
    case ModuleKind kind:
      if (!context.mounted) return;
      final name = await askText(context, kindName(l, kind), initial: kindName(l, kind), label: l.labelName);
      if (name == null) return;
      final id = await ModuleDao(db).createModule(nexusRef: nexusId, parentId: parentId, name: name, kind: kind);
      refreshTree(ref, nexusId);
      router.push(RecentView.locationFor(nexusId, id));
    case 'template':
      if (!context.mounted) return;
      final spec = await pickTemplate(context);
      if (spec != null && context.mounted) await createFromTemplate(context, ref, nexusId, parentId, spec);
    case 'mddx':
      final res = await FilePicker.platform.pickFiles(withData: true);
      final bytes = res?.files.firstOrNull?.bytes;
      if (bytes == null) return;
      final id = await Mddx.import(db, nexusId, parentId, bytes);
      refreshTree(ref, nexusId);
      if (id != null) {
        router.push(RecentView.locationFor(nexusId, id));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.mddxNotModule)));
      }
    case 'csv':
      router.push('/csv/$nexusId');
  }
}

class _KindSheet extends StatefulWidget {
  const _KindSheet();

  @override
  State<_KindSheet> createState() => _KindSheetState();
}

class _KindSheetState extends State<_KindSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final q = _q.trim().toLowerCase();
    bool hit(ModuleKind k) {
      final i = moduleKindInfo[k]!;
      return q.isEmpty ||
          [i.label, i.description, kindName(l, k), kindDesc(l, k), k.id].any((s) => s.toLowerCase().contains(q));
    }

    String cat(ModuleCategory c) => switch (c) {
          ModuleCategory.structure => l.kindCatStructure,
          ModuleCategory.view => l.kindCatView,
          ModuleCategory.data => l.kindCatData,
        };
    String sub(String k) => switch (k) {
          'notes' => l.kindGroupNotes,
          'data' => l.kindGroupData,
          'mapTime' => l.kindGroupMapTime,
          'story' => l.kindGroupStory,
          _ => l.kindGroupDraw,
        };
    final rows = <Widget>[];
    ModuleCategory? last;
    for (final (c, s, kinds) in kindGroups) {
      final shown = kinds.where(hit).toList();
      if (shown.isEmpty) continue;
      if (c != last) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
          child: Text(cat(c).toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
        ));
        last = c;
      }
      if (s != null) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(sub(s), style: theme.textTheme.labelMedium),
        ));
      }
      for (final k in shown) {
        final i = moduleKindInfo[k]!;
        rows.add(ListTile(
          dense: true,
          leading: Icon(i.icon),
          title: Text(kindName(l, k)),
          subtitle: Text(kindDesc(l, k), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.pop(context, k),
        ));
      }
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.labelSearch, isDense: true),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(children: [
              if (q.isEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.auto_awesome_mosaic_outlined),
                  title: Text(l.fromTemplate),
                  onTap: () => Navigator.pop(context, 'template'),
                ),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: Text(l.mddxImport),
                  onTap: () => Navigator.pop(context, 'mddx'),
                ),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: Text(l.csvImportTitle),
                  onTap: () => Navigator.pop(context, 'csv'),
                ),
                const Divider(),
              ],
              ...rows,
            ]),
          ),
        ]),
      ),
    );
  }
}

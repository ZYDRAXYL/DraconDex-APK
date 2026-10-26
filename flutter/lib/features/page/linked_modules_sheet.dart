import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/viewer_model.dart';
import '../../data/services/linked_modules.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/ddx_field.dart';
import '../../widgets/ddx_glass.dart';
import '../../widgets/ddx_icon_button.dart';
import '../../widgets/ddx_list.dart';
import 'views/graph_view.dart' show hexColor;
import 'views/view_common.dart';

/// Procress 28 part 2 — the 🔗 on a module page (EXE hub/page-head.js
/// openPageLinksPopup): which modules this one is linked to, and a search to
/// link another. A link made here is a module ↔ module relation; one that
/// comes from a [[link]] is listed but not removable here — it goes with
/// the text.
Future<void> showLinkedModulesSheet(BuildContext context, ModuleModel module) => showDdxSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LinkedModulesSheet(module: module),
    );

class _LinkedModulesSheet extends ConsumerStatefulWidget {
  const _LinkedModulesSheet({required this.module});
  final ModuleModel module;

  @override
  ConsumerState<_LinkedModulesSheet> createState() => _LinkedModulesSheetState();
}

class _LinkedModulesSheetState extends ConsumerState<_LinkedModulesSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  ({int nexusId, int moduleId}) get _arg => (nexusId: widget.module.nexusRef, moduleId: widget.module.id);

  Future<void> _change(Future<void> Function(Database db) op) async {
    await op(await ref.read(databaseProvider.future));
    ref.invalidate(linkedModulesProvider(_arg));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final linked = ref.watch(linkedModulesProvider(_arg)).valueOrNull ?? const <LinkedModule>[];
    final index = ref.watch(nexusIndexProvider(widget.module.nexusRef)).valueOrNull ?? const <IndexedItem>[];
    final modules = [
      for (final it in index)
        if (it.itemKind == 'module' && it.moduleId != widget.module.id && it.moduleKind != 'collector') it,
    ];
    final byId = {for (final e in linked) e.id: e};
    final q = _q.text.trim().toLowerCase();
    final mine = [for (final m in modules) if (byId.containsKey(m.moduleId)) m];
    final others = q.isEmpty ? const <IndexedItem>[] : [for (final m in modules) if (!byId.containsKey(m.moduleId) && m.name.toLowerCase().contains(q)) m].take(30).toList();
    Widget row(IndexedItem m) {
      final e = byId[m.moduleId];
      final how = e == null ? null : [if (e.relationId != null) l.pageLinkDirect, if (e.wiki) l.pageLinkViaWiki].join(' · ');
      return DdxListTile(
        key: ValueKey('link-${m.moduleId}'),
        density: DdxDensity.compact,
        leading: Icon(moduleKindInfo[ModuleKind.fromId(m.moduleKind)]?.icon ?? Icons.folder_outlined, size: 18, color: hexColor(m.colorCode)),
        title: m.name,
        meta: how,
        selected: e != null,
        trailing: [
          if (e?.relationId != null)
            DdxIconButton(
              icon: Icons.close,
              tooltip: l.pageLinkRemove,
              size: DdxIconSize.sm,
              onPressed: () => _change((db) => unlinkModules(db, e!.relationId!)),
            ),
        ],
        onTap: e != null
            ? () => openKey(context, ref, 'module_${m.moduleId}')
            : () => _change((db) => linkModules(db, widget.module.nexusRef, widget.module.id, m.moduleId)),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.pageLinksTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DdxField(
            key: const ValueKey('page-link-search'),
            controller: _q,
            hint: l.pageLinkSearch,
            prefixIcon: const Icon(Icons.search, size: 18),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (mine.isEmpty)
                Padding(padding: const EdgeInsets.all(12), child: Text(l.pageLinksNone, style: Theme.of(context).textTheme.bodySmall))
              else
                for (final m in mine) row(m),
              for (final m in others) row(m),
            ]),
          ),
        ]),
      ),
    );
  }
}

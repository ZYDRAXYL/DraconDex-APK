import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/dao/classifier_dao.dart';
import '../../data/dao/hashtag_dao.dart';
import '../../data/models/classifier_model.dart';
import '../../data/models/hashtag_model.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/services/search_service.dart';
import '../../data/services/vault_snapshot_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import 'block_options.dart';
import 'component_registry.dart';
import 'page_providers.dart';
import 'views/view_common.dart';

/// The site components on the phone (APP Procress 16 part 3b; EXE
/// renderer/page/components/site.js): a Classifier as a table, a search box,
/// and the page's categories. Link text sits with the other link components
/// in wiki_components.dart.

Widget _muted(BuildContext context, String text) =>
    Text(text, style: TextStyle(color: context.ddx.textMuted));

// ── Data table ─────────────────────────────────────────────────────────────

typedef _Cls = ({List<ClassifierFieldModel> fields, List<ClassifierItemModel> items, Map<int, Map<int, String?>> values});

final _classifierProvider = FutureProvider.autoDispose.family<_Cls, int>((ref, id) async {
  final dao = ClassifierDao(await ref.watch(databaseProvider.future));
  return (fields: await dao.getFields(id), items: await dao.getItems(id), values: await dao.getModuleValues(id));
});

/// A field by its key (it rides in the field's options) or, for an older
/// field, its name — EXE pcFindField.
ClassifierFieldModel? _field(List<ClassifierFieldModel> fields, Object? key) =>
    fields.where((f) => f.opts['key'] == key).firstOrNull ?? fields.where((f) => f.description == key).firstOrNull;

class SiteDataTable extends ConsumerWidget {
  final ComponentCtx ctx;
  const SiteDataTable({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    // the Classifier picked in the options, else the page's own when it is one
    final picked = optValue(ctx.block, 'source') as int?;
    final src = picked == null ? ctx.page.module : ref.watch(moduleProvider(picked)).valueOrNull;
    if (src == null || src.kind != ModuleKind.classifier) return _muted(context, l.pcDataTablePick);
    final data = ref.watch(_classifierProvider(src.id)).valueOrNull;
    if (data == null) return const SizedBox(height: 48);

    final chosen = [for (final k in (optValue(ctx.block, 'fields') is List ? optValue(ctx.block, 'fields') as List : const [])) ?_field(data.fields, k)];
    final cols = chosen.isNotEmpty ? chosen : data.fields.where((f) => f.attributeType != 'relation').take(4).toList();
    String val(ClassifierItemModel o, ClassifierFieldModel f) => data.values[o.id]?[f.id] ?? '';

    final needle = '${optValue(ctx.block, 'filter') ?? ''}'.trim().toLowerCase();
    final rows = needle.isEmpty
        ? [...data.items]
        : data.items.where((o) => [o.name, for (final f in data.fields) val(o, f)].join('\n').toLowerCase().contains(needle)).toList();
    final by = _field(data.fields, optValue(ctx.block, 'sortBy'));
    String keyOf(ClassifierItemModel o) => by == null ? o.name : val(o, by);
    final dir = optValue(ctx.block, 'sortDir') == 'desc' ? -1 : 1;
    rows.sort((a, b) {
      final (p, q) = (keyOf(a), keyOf(b));
      final (np, nq) = (num.tryParse(p), num.tryParse(q));
      return dir * (np != null && nq != null ? np.compareTo(nq) : p.compareTo(q));
    });
    final total = rows.length;
    final shown = rows.take((optValue(ctx.block, 'rows') as num? ?? 25).toInt()).toList();
    if (shown.isEmpty) return _muted(context, l.pcNoElements);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          columns: [DataColumn(label: Text(l.labelName)), for (final f in cols) DataColumn(label: Text(f.description))],
          rows: [
            for (final o in shown)
              DataRow(cells: [
                DataCell(Text(o.name.isEmpty ? '—' : o.name, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    onTap: () => openKey(context, ref, 'cobj_${o.id}')),
                for (final f in cols) DataCell(Text(val(o, f))),
              ]),
          ],
        ),
      ),
      if (total > shown.length) Padding(padding: const EdgeInsets.only(top: 4), child: _muted(context, '${shown.length} / $total')),
    ]);
  }
}

// ── Search box ─────────────────────────────────────────────────────────────

class SiteSearch extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const SiteSearch({super.key, required this.ctx});

  @override
  ConsumerState<SiteSearch> createState() => _SiteSearchState();
}

class _SiteSearchState extends ConsumerState<SiteSearch> {
  final _q = TextEditingController();
  SearchService? _service;
  Timer? _timer;
  List<SearchHit>? _hits;
  ({int id, Set<int> modules})? _scope;

  @override
  void dispose() {
    _timer?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.isEmpty) return setState(() => _hits = null);
    final db = await ref.read(databaseProvider.future);
    final service = _service ??= SearchService(db);
    final nx = widget.ctx.nexusId;
    final hits = {for (final h in [...await service.things(q, nexusId: nx), ...await service.content(q, nexusId: nx)]) h.key: h}.values.toList();
    // one module and everything under it (EXE pcSearchScope), gathered once per scope
    final scopeId = optValue(widget.ctx.block, 'scope') as int?;
    if (scopeId != null && _scope?.id != scopeId) {
      _scope = (id: scopeId, modules: (await VaultSnapshotService.collectModuleSubtreeIds(db, nx, scopeId)).toSet());
    }
    if (!mounted || _q.text.trim() != q) return; // a newer query won
    setState(() => _hits = scopeId == null ? hits : hits.where((h) => _scope!.modules.contains(h.moduleId)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hits = _hits;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _q,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchHint, isDense: true, border: const OutlineInputBorder()),
        textInputAction: TextInputAction.search,
        onChanged: (_) {
          _timer?.cancel();
          _timer = Timer(const Duration(milliseconds: 200), _run);
        },
        onSubmitted: (_) {
          final first = _hits?.firstOrNull;
          if (first != null) GoRouter.of(context).push(first.location);
        },
      ),
      if (hits != null && hits.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: _muted(context, l.leftSearchNone)),
      for (final h in hits?.take(12) ?? const <SearchHit>[])
        ListTile(
          dense: true,
          title: Text(h.title.isEmpty ? h.key : h.title),
          subtitle: h.snippet == null ? Text(h.moduleName) : Text(h.snippet!.replaceAll(RegExp(r'[\[\]]'), ''), maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => GoRouter.of(context).push(h.location),
        ),
    ]);
  }
}

// ── Categories of this page ────────────────────────────────────────────────

final _tagsProvider = FutureProvider.autoDispose.family<List<HashtagModel>, int>((ref, moduleId) async =>
    HashtagDao(await ref.watch(databaseProvider.future)).getModuleTags(moduleId));

/// Wikipedia's bar at the foot of an article (EXE pageCategoriesHtml): the
/// page's tags and the folder it sits in; nothing when it has neither.
class SiteCategories extends ConsumerWidget {
  final ComponentCtx ctx;
  const SiteCategories({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final m = ctx.page.module;
    final tags = ctx.itemKey == null ? ref.watch(_tagsProvider(m.id)).valueOrNull ?? const <HashtagModel>[] : const <HashtagModel>[];
    final folder = m.parentId == null ? null : ref.watch(moduleProvider(m.parentId!)).valueOrNull;
    if (tags.isEmpty && folder == null) {
      return ref.watch(arrangeModeProvider(ctx.key)) ? _muted(context, l.pcCategories) : const SizedBox.shrink();
    }
    return Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('${l.pcCategories}:', style: Theme.of(context).textTheme.bodySmall),
      // ponytail: a tag reads as a chip; the desktop's category pages have no phone screen yet
      for (final t in tags) Chip(visualDensity: VisualDensity.compact, label: Text('#${t.name}')),
      if (folder != null)
        ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.folder_outlined, size: 16),
          label: Text(folder.name),
          onPressed: () => GoRouter.of(context).push(RecentView.locationFor(ctx.nexusId, folder.id)),
        ),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/problems_service.dart';
import '../../providers/db_providers.dart';
import '../../widgets/ddx_list.dart';
import '../page/views/view_common.dart';
import '../../widgets/ddx_glass.dart';

final problemsProvider = FutureProvider.autoDispose.family<List<Problem>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return ProblemsService.list(db, nexusId);
});

/// Problems (EXE hub/problems.js): grouped by type, each group with its
/// count and folding (UX-LAYOUT §12.4); a row opens its place.
class ProblemsScreen extends ConsumerStatefulWidget {
  final int nexusId;
  const ProblemsScreen({super.key, required this.nexusId});

  @override
  ConsumerState<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends ConsumerState<ProblemsScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final nexusId = widget.nexusId;
    final list = ref.watch(problemsProvider(nexusId));
    String title(String t) => switch (t) {
          'link' => l.problemsLinks,
          'empty' => l.problemsEmpty,
          _ => l.problemsRelations,
        };
    IconData icon(String t) => switch (t) {
          'link' => Icons.link_off,
          'empty' => Icons.inbox_outlined,
          _ => Icons.share_outlined,
        };
    return Scaffold(
      appBar: DdxGlassBar(child: AppBar(title: Text(l.problemsTitle), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(problemsProvider(nexusId))),
      ])),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ps) {
          if (ps.isEmpty) return DdxEmptyState(icon: Icons.check_circle_outline, message: l.problemsNone);
          final shown = [for (final p in ps) if (ddxMatches(_filter, [p.name, p.detail])) p];
          // each type's group, its rows built as they scroll in — a vault
          // with thousands of problems builds only what shows
          final byType = {
            for (final t in const ['link', 'empty', 'relation'])
              if (shown.where((p) => p.type == t).toList() case final rows when rows.isNotEmpty) t: rows,
          };
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: DdxListHeader(count: shown.length, onFilterChanged: (v) => setState(() => _filter = v)),
            ),
            if (shown.isEmpty)
              SliverToBoxAdapter(child: DdxEmptyState(icon: Icons.filter_list_off, message: l.listNoMatch)),
            for (final e in byType.entries)
              DdxListSection.sliver(
                storageId: 'problems-${e.key}',
                title: title(e.key),
                count: e.value.length,
                itemCount: e.value.length,
                itemBuilder: (context, i) {
                  final p = e.value[i];
                  return DdxListTile(
                    icon: icon(e.key),
                    title: p.name,
                    meta: p.detail,
                    onTap: p.key == null ? null : () => openKey(context, ref, p.key!),
                  );
                },
              ),
          ]);
        },
      ),
    );
  }
}

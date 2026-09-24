import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/problems_service.dart';
import '../../providers/db_providers.dart';
import '../page/views/view_common.dart';

final problemsProvider = FutureProvider.autoDispose.family<List<Problem>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return ProblemsService.list(db, nexusId);
});

/// Problems (EXE hub/problems.js): grouped by type; a row opens its place.
class ProblemsScreen extends ConsumerWidget {
  final int nexusId;
  const ProblemsScreen({super.key, required this.nexusId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
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
      appBar: AppBar(title: Text(l.problemsTitle), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(problemsProvider(nexusId))),
      ]),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ps) => ps.isEmpty
            ? Center(child: Text(l.problemsNone))
            : ListView(children: [
                for (final t in const ['link', 'empty', 'relation'])
                  if (ps.where((p) => p.type == t).toList() case final rows when rows.isNotEmpty) ...[
                    ListTile(title: Text('${title(t)} (${rows.length})', style: Theme.of(context).textTheme.titleSmall)),
                    for (final p in rows)
                      ListTile(
                        dense: true,
                        leading: Icon(icon(t), size: 20),
                        title: Text(p.name),
                        subtitle: Text(p.detail),
                        onTap: p.key == null ? null : () => openKey(context, ref, p.key!),
                      ),
                  ],
              ]),
      ),
    );
  }
}

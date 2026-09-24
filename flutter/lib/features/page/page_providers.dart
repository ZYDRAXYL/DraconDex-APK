import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import 'component_registry.dart';

/// Which page: a module's own (itemKey null), the shared element layout
/// ('*'), or one element's page.
class PageKey {
  final int moduleId;
  final String? itemKey;
  const PageKey(this.moduleId, [this.itemKey]);

  @override
  bool operator ==(Object other) => other is PageKey && other.moduleId == moduleId && other.itemKey == itemKey;

  @override
  int get hashCode => Object.hash(moduleId, itemKey);
}

class PageData {
  final ModuleModel module;
  final List<PageBlock> blocks;
  final PageSource from;
  final List<PageBlock> props;
  const PageData({required this.module, required this.blocks, required this.from, required this.props});

  /// Top-level blocks, in order.
  List<PageBlock> get top => [for (final b in blocks) if (b.parentId == null) b];

  /// A columns block's children, per column.
  List<List<PageBlock>> columnsOf(PageBlock columns) {
    final n = ((columns.config['n'] as num?)?.toInt() ?? 2).clamp(1, 3);
    final out = List.generate(n, (_) => <PageBlock>[]);
    for (final b in blocks) {
      if (b.parentId == columns.id) out[b.column.clamp(0, n - 1)].add(b);
    }
    return out;
  }
}

final pageBlockDaoProvider = FutureProvider<PageBlockDao>((ref) async => PageBlockDao(await ref.watch(databaseProvider.future)));

/// A page, laid out the first time it opens (EXE loadModulePage: ensure,
/// then list). Invalidate after any change to its blocks.
final pageProvider = FutureProvider.autoDispose.family<PageData?, PageKey>((ref, key) async {
  final module = await ref.watch(moduleProvider(key.moduleId).future);
  if (module == null) return null;
  final dao = await ref.watch(pageBlockDaoProvider.future);
  final db = await ref.watch(databaseProvider.future);
  if (key.itemKey == null) {
    final ui = await db.rawQuery(
        "SELECT ui_key, ui_value FROM module_ui WHERE module_ref=? AND ui_key IN ('activeView','view')", [module.id]);
    final view = {for (final r in ui) r['ui_key']: r['ui_value'] as String?};
    await dao.ensurePage(module.id, null, defaultPageLayout(module.kind, view['activeView'] ?? view['view']));
  } else {
    await dao.ensurePage(module.id, '*', itemPageLayout());
  }
  final list = await dao.list(module.id, key.itemKey);
  final props = await dao.props(module.id, key.itemKey);
  return PageData(module: module, blocks: list.blocks, from: list.from, props: props);
});

/// Arrange mode, per page (EXE S.arrange per pane).
final arrangeModeProvider = StateProvider.autoDispose.family<bool, PageKey>((ref, key) => false);

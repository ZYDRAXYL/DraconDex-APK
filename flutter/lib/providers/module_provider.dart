import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/module_model.dart';
import 'db_providers.dart';

final nexusesProvider = FutureProvider<List<NexusModel>>((ref) async {
  final dao = ref.watch(moduleDaoProvider);
  return dao.when(
    data: (d) => d.getNexuses(),
    loading: () => Future.value([]),
    // Was `Future.value([])`: a DB-open failure looked identical to "no
    // Nexus yet" — an empty list either way — so a real error had no way to
    // reach the screen. Propagating it lets nexusesAsync.when's error branch
    // actually show it instead of a misleadingly-empty list.
    error: (e, s) => Future<List<NexusModel>>.error(e, s),
  );
});

final nexusProvider = FutureProvider.family<NexusModel?, int>((ref, id) async {
  final dao = ref.watch(moduleDaoProvider);
  return dao.when(
    data: (d) => d.getNexus(id),
    loading: () => Future.value(null),
    error: (e, s) => Future<NexusModel?>.error(e, s),
  );
});

/// Key for [moduleChildrenProvider]: the module list one drill-down level
/// shows — every module directly under [parentId] inside [nexusId]
/// ([parentId] null = the Nexus root).
class ModuleChildrenKey {
  final int nexusId;
  final int? parentId;
  const ModuleChildrenKey(this.nexusId, this.parentId);

  @override
  bool operator ==(Object other) =>
      other is ModuleChildrenKey && other.nexusId == nexusId && other.parentId == parentId;

  @override
  int get hashCode => Object.hash(nexusId, parentId);
}

final moduleChildrenProvider =
    FutureProvider.family<List<ModuleModel>, ModuleChildrenKey>((ref, key) async {
  final dao = ref.watch(moduleDaoProvider);
  return dao.when(
    data: (d) => d.getModules(key.nexusId, key.parentId),
    loading: () => Future.value([]),
    error: (e, s) => Future<List<ModuleModel>>.error(e, s),
  );
});

final moduleProvider = FutureProvider.family<ModuleModel?, int>((ref, id) async {
  final dao = ref.watch(moduleDaoProvider);
  return dao.when(
    data: (d) => d.getModule(id),
    loading: () => Future.value(null),
    error: (e, s) => Future<ModuleModel?>.error(e, s),
  );
});

/// Ancestor chain (root-first, excluding the module itself) for breadcrumbs.
final moduleBreadcrumbProvider = FutureProvider.family<List<ModuleModel>, int>((ref, id) async {
  final dao = ref.watch(moduleDaoProvider);
  return dao.when(
    data: (d) => d.getAncestors(id),
    loading: () => Future.value([]),
    error: (e, s) => Future<List<ModuleModel>>.error(e, s),
  );
});

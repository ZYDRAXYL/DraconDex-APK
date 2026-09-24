import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dao/module_dao.dart';
import '../data/dao/viewer_dao.dart';
import '../data/models/module_model.dart';
import '../data/models/viewer_model.dart';
import 'db_providers.dart';

/// Whether the app bar and the Navibar are showing (APK V3 focus, APP
/// docs/APK-V3.md §10.5): the phone shell hides both while the user scrolls
/// down and brings them back on the way up. Only the phone shell ever sets it
/// false — a tablet keeps its chrome.
final chromeVisibleProvider = StateProvider<bool>((ref) => true);

/// Every module and element of one Nexus, as the vault index has them — what
/// the breadcrumb's "go to" field and an element page's crumb look names up
/// in. Auto-disposed, so a sheet that opens after an edit somewhere else
/// reads the vault again rather than a list from earlier in the session.
final nexusIndexProvider = FutureProvider.autoDispose.family<List<IndexedItem>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return ViewerDao(db).index(nexusId);
});

/// The pinned modules of one Nexus, at any depth — the tablet rail lists them
/// (APP docs/APK-V3.md §10.1).
final pinnedModulesProvider = FutureProvider.family<List<ModuleModel>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return ModuleDao(db).getPinnedModules(nexusId);
});

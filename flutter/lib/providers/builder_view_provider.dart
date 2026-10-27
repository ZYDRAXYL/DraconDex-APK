import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_providers.dart';

/// How the Builder lays out a collection (the Nexus list, or the modules
/// nested under one). Chosen from the Navibar's "view" button and applied
/// app-wide — the same choice the electron side's layout picker makes.
enum BuilderViewMode {
  list(Icons.view_list_outlined, 'list'),
  grid(Icons.grid_view_outlined, 'large'),
  compact(Icons.view_headline_outlined, 'small'),
  // Procress 29 part 7: name · kind · updated · items, a column each
  details(Icons.table_rows_outlined, 'details');

  const BuilderViewMode(this.icon, this.folderView);

  final IconData icon;

  /// The same choice as the desktop's folder page stores it in a folder's
  /// module_ui `folderView` (EXE hub/folder-page.js): large · small · list · details.
  final String folderView;

  static BuilderViewMode fromId(String? id) => BuilderViewMode.values.firstWhere(
        (m) => m.name == id,
        orElse: () => BuilderViewMode.list,
      );

  static BuilderViewMode? fromFolderView(String? v) {
    for (final m in BuilderViewMode.values) {
      if (m.folderView == v) return m;
    }
    return null;
  }
}

/// A folder's own view (module_ui `folderView`), shared with the desktop
/// through the vault — null when the folder was never given one, and then
/// the app-wide choice applies (Procress 29 part 7).
final folderViewProvider = FutureProvider.family<BuilderViewMode?, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final r = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='folderView'", [moduleId]);
  return r.isEmpty ? null : BuilderViewMode.fromFolderView(r.first['ui_value'] as String?);
});

Future<void> setFolderView(WidgetRef ref, int moduleId, BuilderViewMode mode) async {
  final db = await ref.read(databaseProvider.future);
  await db.rawInsert(
    "INSERT INTO module_ui (module_ref, ui_key, ui_value) VALUES (?, 'folderView', ?) "
    'ON CONFLICT(module_ref, ui_key) DO UPDATE SET ui_value=excluded.ui_value',
    [moduleId, mode.folderView],
  );
  ref.invalidate(folderViewProvider(moduleId));
}

class BuilderViewModeNotifier extends Notifier<BuilderViewMode> {
  static const _key = 'builder_view_mode';

  @override
  BuilderViewMode build() {
    _load();
    return BuilderViewMode.list;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = BuilderViewMode.fromId(prefs.getString(_key));
  }

  Future<void> set(BuilderViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final builderViewModeProvider =
    NotifierProvider<BuilderViewModeNotifier, BuilderViewMode>(BuilderViewModeNotifier.new);

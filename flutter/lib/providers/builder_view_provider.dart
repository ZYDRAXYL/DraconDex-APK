import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the Builder lays out a collection (the Nexus list, or the modules
/// nested under one). Chosen from the Navibar's "view" button and applied
/// app-wide — the same choice the electron side's layout picker makes.
enum BuilderViewMode {
  list(Icons.view_list_outlined),
  grid(Icons.grid_view_outlined),
  compact(Icons.view_headline_outlined);

  const BuilderViewMode(this.icon);

  final IconData icon;

  static BuilderViewMode fromId(String? id) => BuilderViewMode.values.firstWhere(
        (m) => m.name == id,
        orElse: () => BuilderViewMode.list,
      );
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

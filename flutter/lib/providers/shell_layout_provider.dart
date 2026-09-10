import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/layout/breakpoints.dart';

/// Persisted chrome state for the tablet/desktop shell — how wide the hub
/// panel is, whether it and the rail's labels are showing, and which of the
/// panel's sections are open. Phone-shaped windows never read it (they have
/// the Navibar instead), but it is kept app-wide rather than per-screen so a
/// rotation or a Split View resize lands back on the same arrangement.
class ShellLayoutState {
  /// Whether the hub panel is on screen at all (the rail's panel toggle).
  final bool hubVisible;

  /// Width the user dragged the hub panel to.
  final double hubWidth;

  /// Rail showing labels next to its icons, the way the Electron rail does
  /// once it is dragged past a certain width.
  final bool railExtended;

  /// Whether the panel's folder-views section is unfolded. The nest itself
  /// has no such flag — it is what the panel is for, so it is always shown.
  final bool recentSectionOpen;

  const ShellLayoutState({
    this.hubVisible = true,
    this.hubWidth = kHubPanelDefaultWidth,
    this.railExtended = false,
    this.recentSectionOpen = false,
  });

  ShellLayoutState copyWith({
    bool? hubVisible,
    double? hubWidth,
    bool? railExtended,
    bool? recentSectionOpen,
  }) {
    return ShellLayoutState(
      hubVisible: hubVisible ?? this.hubVisible,
      hubWidth: hubWidth ?? this.hubWidth,
      railExtended: railExtended ?? this.railExtended,
      recentSectionOpen: recentSectionOpen ?? this.recentSectionOpen,
    );
  }
}

class ShellLayoutNotifier extends Notifier<ShellLayoutState> {
  static const _keyHubVisible = 'shell_hub_visible';
  static const _keyHubWidth = 'shell_hub_width';
  static const _keyRailExtended = 'shell_rail_extended';
  static const _keyRecentOpen = 'shell_section_recent';

  @override
  ShellLayoutState build() {
    _load();
    return const ShellLayoutState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ShellLayoutState(
      hubVisible: prefs.getBool(_keyHubVisible) ?? true,
      hubWidth: (prefs.getDouble(_keyHubWidth) ?? kHubPanelDefaultWidth)
          .clamp(kHubPanelMinWidth, kHubPanelMaxWidth),
      railExtended: prefs.getBool(_keyRailExtended) ?? false,
      recentSectionOpen: prefs.getBool(_keyRecentOpen) ?? false,
    );
  }

  Future<void> setHubVisible(bool visible) async {
    state = state.copyWith(hubVisible: visible);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHubVisible, visible);
  }

  Future<void> toggleHub() => setHubVisible(!state.hubVisible);

  /// Live during a drag of the panel's edge: updates state on every frame but
  /// only writes the preference once, from [commitHubWidth].
  void setHubWidth(double width) {
    state = state.copyWith(hubWidth: width.clamp(kHubPanelMinWidth, kHubPanelMaxWidth));
  }

  Future<void> commitHubWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyHubWidth, state.hubWidth);
  }

  Future<void> setRailExtended(bool extended) async {
    state = state.copyWith(railExtended: extended);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRailExtended, extended);
  }

  Future<void> toggleRailExtended() => setRailExtended(!state.railExtended);

  Future<void> setRecentSectionOpen(bool open) async {
    state = state.copyWith(recentSectionOpen: open);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecentOpen, open);
  }
}

final shellLayoutProvider =
    NotifierProvider<ShellLayoutNotifier, ShellLayoutState>(ShellLayoutNotifier.new);

/// Which rows of the hub panel's tree are unfolded, as [hubNodeKey] strings.
/// In-memory on purpose: it describes a reading position inside one session,
/// and restoring a half-expanded tree from days ago on cold start would fetch
/// every remembered level before the first frame.
class HubTreeExpansionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    state = state.contains(key)
        ? (state.toSet()..remove(key))
        : (state.toSet()..add(key));
  }

  void expand(Iterable<String> keys) {
    final next = state.toSet()..addAll(keys);
    if (next.length == state.length) return;
    state = next;
  }
}

/// Identity of one row in the hub tree: a Nexus root, or a module inside one.
String hubNodeKey(int nexusId, int? moduleId) => '$nexusId:${moduleId ?? 'root'}';

final hubTreeExpansionProvider =
    NotifierProvider<HubTreeExpansionNotifier, Set<String>>(HubTreeExpansionNotifier.new);

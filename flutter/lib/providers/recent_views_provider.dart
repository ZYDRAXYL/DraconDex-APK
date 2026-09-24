import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/recent_view_model.dart';

/// The pages the user has open (APK V3, APP docs/APK-V3.md §10.2) — the
/// phone's card switcher and the tablet's tab row both draw this list.
///
/// It was the Builder's "folder views" history before V3: the places the app
/// was most recently opened at. It still fills itself the same way — every
/// page that opens is [record]ed — but an entry now stays until the user
/// closes it, and the order is the TAB order: a page that is already open
/// keeps its place when it is opened again, so tapping a tab does not
/// reshuffle the row under the finger. [byRecency] is the switcher's order.
///
/// Backed by the same SharedPreferences key, so the history an older build
/// kept arrives as the first open pages rather than being lost.
class RecentViewsNotifier extends Notifier<List<RecentView>> {
  static const _key = 'recent_views';

  /// Past this many, opening another page closes the least recently used
  /// one — a row of tabs that only grows stops being a way back to anything.
  static const maxEntries = 20;

  @override
  List<RecentView> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = RecentView.decodeList(prefs.getString(_key));
    // A record() can land while this read is in flight (the first screen
    // opens immediately on cold start); keep those entries and drop only the
    // stored duplicates of them, otherwise the just-opened page disappears.
    final live = state;
    if (live.isEmpty) {
      state = loaded;
      return;
    }
    final liveKeys = live.map((v) => v.key).toSet();
    state = _capped([...loaded.where((v) => !liveKeys.contains(v.key)), ...live]);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, RecentView.encodeList(state));
  }

  /// Drops the least recently opened pages until the list fits.
  static List<RecentView> _capped(List<RecentView> views) {
    if (views.length <= maxEntries) return views;
    final keep = (byRecency(views).take(maxEntries).map((v) => v.key)).toSet();
    return views.where((v) => keep.contains(v.key)).toList();
  }

  /// Newest first — the order the phone's switcher shows its cards in.
  static List<RecentView> byRecency(List<RecentView> views) =>
      [...views]..sort((a, b) => b.openedAt.compareTo(a.openedAt));

  /// Opens [view]: a page already open keeps its place and is refreshed (its
  /// title and colour too, so a rename shows up here); a new one is added at
  /// the end.
  Future<void> record(RecentView view) async {
    final i = state.indexWhere((v) => v.key == view.key);
    if (i >= 0) {
      state = [...state]..[i] = view;
    } else {
      state = _capped([...state, view]);
    }
    await _persist();
  }

  /// Closes one page.
  Future<void> close(String key) async {
    state = state.where((v) => v.key != key).toList();
    await _persist();
  }

  /// Kept for the callers that drop a page because what it showed is gone
  /// (a deleted module) rather than because the user closed it.
  Future<void> remove(String key) => close(key);

  /// Closes every page inside [nexusId] — used when that Nexus is deleted,
  /// so no tab offers a jump into a tree that is gone.
  Future<void> removeForNexus(int nexusId) async {
    state = state.where((v) => v.nexusId != nexusId).toList();
    await _persist();
  }

  /// Closes every element page of [moduleId] and the module's own page.
  Future<void> removeForModule(int nexusId, int moduleId) async {
    state = state.where((v) => !(v.nexusId == nexusId && v.moduleId == moduleId)).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}

final recentViewsProvider =
    NotifierProvider<RecentViewsNotifier, List<RecentView>>(RecentViewsNotifier.new);

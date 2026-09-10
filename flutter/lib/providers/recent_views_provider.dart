import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/recent_view_model.dart';

/// The Builder's "folder views" history — the places the app was most
/// recently opened at, newest first. Backed by SharedPreferences, so it is
/// device-local and survives an app restart (and a vault import).
class RecentViewsNotifier extends Notifier<List<RecentView>> {
  static const _key = 'recent_views';

  /// Enough to cover "where was I?" without turning the sheet into a log.
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
    // stored duplicates of them, otherwise the just-opened view disappears.
    final live = state;
    if (live.isEmpty) {
      state = loaded;
      return;
    }
    final liveKeys = live.map((v) => v.key).toSet();
    state = [...live, ...loaded.where((v) => !liveKeys.contains(v.key))]
        .take(maxEntries)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, RecentView.encodeList(state));
  }

  /// Moves [view] to the front, replacing any earlier visit to the same
  /// place (its title/color are refreshed in the process, so a rename shows
  /// up here too).
  Future<void> record(RecentView view) async {
    final rest = state.where((v) => v.key != view.key);
    state = [view, ...rest].take(maxEntries).toList();
    await _persist();
  }

  Future<void> remove(String key) async {
    state = state.where((v) => v.key != key).toList();
    await _persist();
  }

  /// Drops every entry pointing into [nexusId] — used when that Nexus is
  /// deleted, so the sheet can't offer a jump into a tree that is gone.
  Future<void> removeForNexus(int nexusId) async {
    state = state.where((v) => v.nexusId != nexusId).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}

final recentViewsProvider =
    NotifierProvider<RecentViewsNotifier, List<RecentView>>(RecentViewsNotifier.new);

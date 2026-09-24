import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dracondex/data/models/recent_view_model.dart';
import 'package:dracondex/features/builder/breadcrumb_title.dart';
import 'package:dracondex/features/builder/builder_shell.dart';
import 'package:dracondex/features/builder/hub_location.dart';
import 'package:dracondex/providers/recent_views_provider.dart';

/// Open pages (APK V3, APP docs/APK-V3.md §10.2) and the addresses they,
/// search and the breadcrumb navigate by (§10.3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RecentView page(int nexus, int? module, {String? item, String title = 'p', int at = 0}) => RecentView(
        nexusId: nexus,
        moduleId: module,
        itemKey: item,
        title: title,
        nexusName: 'World',
        openedAt: DateTime(2026, 1, 1).add(Duration(minutes: at)),
      );

  Future<ProviderContainer> container({List<RecentView> stored = const []}) async {
    SharedPreferences.setMockInitialValues({if (stored.isNotEmpty) 'recent_views': RecentView.encodeList(stored)});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(recentViewsProvider);
    // Let the stored list load.
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  group('open pages', () {
    test('opening a page again keeps its place and refreshes it', () async {
      final c = await container();
      final n = c.read(recentViewsProvider.notifier);
      await n.record(page(1, 1, title: 'A', at: 0));
      await n.record(page(1, 2, title: 'B', at: 1));
      await n.record(page(1, 1, title: 'A renamed', at: 2));
      expect(c.read(recentViewsProvider).map((v) => v.title), ['A renamed', 'B']);
      expect(RecentViewsNotifier.byRecency(c.read(recentViewsProvider)).map((v) => v.title), ['A renamed', 'B']);
    });

    test('close, close a module with its element pages, close all', () async {
      final c = await container();
      final n = c.read(recentViewsProvider.notifier);
      await n.record(page(1, 1));
      await n.record(page(1, 1, item: 'cobj_4'));
      await n.record(page(1, 2));
      await n.record(page(2, null));
      await n.close(RecentView.keyFor(2, null));
      expect(c.read(recentViewsProvider).length, 3);
      await n.removeForModule(1, 1);
      expect(c.read(recentViewsProvider).map((v) => v.key), ['1:2']);
      await n.clear();
      expect(c.read(recentViewsProvider), isEmpty);
    });

    test('past the cap, the least recently opened page closes', () async {
      final c = await container();
      final n = c.read(recentViewsProvider.notifier);
      for (var i = 0; i < RecentViewsNotifier.maxEntries; i++) {
        await n.record(page(1, i, at: i));
      }
      // Module 0 is reopened, so module 1 is now the stalest.
      await n.record(page(1, 0, at: 100));
      await n.record(page(1, 999, at: 101));
      final keys = c.read(recentViewsProvider).map((v) => v.key).toList();
      expect(keys.length, RecentViewsNotifier.maxEntries);
      expect(keys, isNot(contains('1:1')));
      expect(keys.first, '1:0');
      expect(keys.last, '1:999');
    });

    test('pages an older build stored still load, and persist again', () async {
      final c = await container(stored: [page(3, 7, title: 'Old')]);
      expect(c.read(recentViewsProvider).single.location, '/hub/3/module/7');
      await c.read(recentViewsProvider.notifier).record(page(3, 8));
      final prefs = await SharedPreferences.getInstance();
      expect(RecentView.decodeList(prefs.getString('recent_views')).length, 2);
    });
  });

  group('addresses', () {
    test('a page key and location, with and without an element', () {
      expect(RecentView.keyFor(1, null), '1:root');
      expect(RecentView.keyFor(1, 2), '1:2');
      expect(RecentView.keyFor(1, 2, 'cobj_3'), '1:2:cobj_3');
      expect(RecentView.locationFor(1, 2, 'cobj_3'), '/hub/1/module/2/item/cobj_3');
      final back = RecentView.decodeList(RecentView.encodeList([page(1, 2, item: 'tlev_9')])).single;
      expect(back.itemKey, 'tlev_9');
      expect(back.location, '/hub/1/module/2/item/tlev_9');
    });

    test('HubLocation reads an element route, and nothing else as one', () {
      final at = HubLocation.parse('/hub/3/module/12/item/cobj_4');
      expect([at.nexusId, at.moduleId, at.itemKey], [3, 12, 'cobj_4']);
      expect(HubLocation.parse('/hub/3/module/12').itemKey, isNull);
      expect(HubLocation.parse('/hub/3/module/12/item/..').itemKey, isNull);
      expect(HubLocation.parse('/search').isHome, isTrue);
    });

    test('Nest goes to the Nexus root from inside one, else to the list', () {
      expect(BuilderNavibar.nestTarget('/hub/3/module/12/item/cobj_4'), '/hub/3');
      expect(BuilderNavibar.nestTarget('/hub/3'), '/');
      expect(BuilderNavibar.nestTarget('/search'), '/');
    });

    test('a long breadcrumb trims its start, never its end', () {
      expect(trimCrumbs([1, 2, 3]).hidden, isEmpty);
      final t = trimCrumbs([1, 2, 3, 4, 5]);
      expect(t.hidden, [1, 2]);
      expect(t.shown, [3, 4, 5]);
    });
  });
}

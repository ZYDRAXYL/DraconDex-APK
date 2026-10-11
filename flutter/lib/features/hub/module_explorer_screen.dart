import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/entity/entity_kinds.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/ddx_list.dart';
import '../../widgets/hiding_app_bar.dart';
import '../../widgets/row_menu.dart';
import '../builder/breadcrumb_title.dart';
import '../builder/view_mode_button.dart';
import '../page/module_page.dart';
import '../page/page_header.dart';
import '../page/page_providers.dart';
import '../page/page_actions.dart';
import '../tools/folder_assets.dart';
import 'dialogs/new_module_sheet.dart';
import 'module_actions.dart';
import 'widgets/module_collection_view.dart';
import 'widgets/nexus_collection_view.dart';

/// One page of the Hub, shown inside the Builder shell: the Nexus root
/// (moduleId null), a single module's own page — its content area (if its
/// kind has one) plus the modules nested under it — or, with [itemKey], one
/// element of that module. Reused recursively: drilling in pushes this same
/// widget again with a deeper moduleId, file-explorer style.
///
/// The title is the page's breadcrumb (APP docs/APK-V3.md §10.3), and the
/// app bar keeps to two actions — the view mode and the page's ⋮ — with the
/// FAB as the one main button (§5).
///
/// Opening one opens it as a page (the Navibar's "open pages").
class ModuleExplorerScreen extends ConsumerStatefulWidget {
  final int nexusId;
  final int? moduleId;

  /// An element page (`cobj_12`) of [moduleId]. The element's own page —
  /// its blocks — arrives with Procress 12 part 2; until then the route
  /// shows the module with the element as the last crumb, so search results
  /// and open pages already have somewhere to land.
  final String? itemKey;

  const ModuleExplorerScreen({super.key, required this.nexusId, this.moduleId, this.itemKey});

  @override
  ConsumerState<ModuleExplorerScreen> createState() => _ModuleExplorerScreenState();
}

class _ModuleExplorerScreenState extends ConsumerState<ModuleExplorerScreen> {
  /// Last recorded entry, as key+title+color — re-records on a rename or a
  /// recolor so the open pages never show a stale label, but not on every
  /// unrelated rebuild.
  String? _recordedSignature;

  /// The header over the rows (UX-LAYOUT §12.4): a filter, and an order —
  /// null is the folder's own (pinned first, then as arranged).
  String _filter = '';
  DdxSort? _sort;

  int get nexusId => widget.nexusId;
  int? get moduleId => widget.moduleId;
  String? get itemKey => widget.itemKey;

  ModuleChildrenKey get _childrenKey => ModuleChildrenKey(nexusId, moduleId);

  /// Opens this screen as a page once whatever it is showing has actually
  /// loaded (a half-resolved '…' title is not worth keeping). Deferred past
  /// the current frame — recording writes provider state, which build() must
  /// not do.
  void _recordOpenPage(NexusModel? nexus, ModuleModel? module, String? itemName) {
    if (nexus == null) return;
    if (moduleId != null && module == null) return;
    if (itemKey != null && itemName == null) return;

    final view = RecentView(
      nexusId: nexusId,
      moduleId: moduleId,
      itemKey: itemKey,
      title: itemName ?? module?.name ?? nexus.name,
      nexusName: nexus.name,
      kindId: module?.kind.id,
      colorCode: module?.colorCode ?? (moduleId == null ? nexus.colorCode : null),
      openedAt: DateTime.now(),
    );
    final signature = '${view.key}|${view.title}|${view.colorCode}';
    if (_recordedSignature == signature) return;
    _recordedSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentViewsProvider.notifier).record(view);
    });
  }

  /// An open page can outlive what it points at — the module or element was
  /// deleted, or it sat under a subtree that was. Landing on one resolves it
  /// to null (loaded, but absent), which is the moment to close the page.
  void _closeIfMissing(AsyncValue<ModuleModel?>? moduleAsync, AsyncValue<String?>? itemAsync) {
    final moduleGone = moduleId != null && moduleAsync != null && moduleAsync.hasValue && moduleAsync.value == null;
    final itemGone = itemKey != null && itemAsync != null && itemAsync.hasValue && itemAsync.value == null;
    if (!moduleGone && !itemGone) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentViewsProvider.notifier).remove(RecentView.keyFor(nexusId, moduleId, itemKey));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nexusAsync = ref.watch(nexusProvider(nexusId));
    final moduleAsync = moduleId == null ? null : ref.watch(moduleProvider(moduleId!));
    final breadcrumbAsync = moduleId == null ? null : ref.watch(moduleBreadcrumbProvider(moduleId!));
    final itemAsync = itemKey == null ? null : ref.watch(_itemNameProvider((nexusId, itemKey!)));
    final childrenAsync = ref.watch(moduleChildrenProvider(_childrenKey));

    final module = moduleAsync?.valueOrNull;
    final nexus = nexusAsync.valueOrNull;
    final itemName = itemAsync?.valueOrNull;
    final viewMode = ref.watch(builderViewModeProvider);
    // Select mode (APP docs/ASSET-PACK.md §1): rows toggle instead of open,
    // and the bottom bar moves what is picked. Back leaves it first.
    final selection = ref.watch(moduleSelectionProvider(_childrenKey));
    final selecting = selection.isNotEmpty;
    void endSelect() => ref.read(moduleSelectionProvider(_childrenKey).notifier).state = const {};

    _recordOpenPage(nexus, module, itemName);
    _closeIfMissing(moduleAsync, itemAsync);

    final crumbs = <Crumb>[
      Crumb(label: nexus?.name ?? '…', nexusId: nexusId),
      for (final a in breadcrumbAsync?.valueOrNull ?? const <ModuleModel>[])
        Crumb(label: a.name, nexusId: nexusId, moduleId: a.id),
      if (moduleId != null) Crumb(label: module?.name ?? '…', nexusId: nexusId, moduleId: moduleId),
      if (itemKey != null) Crumb(label: itemName ?? '…', nexusId: nexusId, moduleId: moduleId, itemKey: itemKey),
    ];

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) endSelect();
      },
      child: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HidingAppBar(
            appBar: AppBar(
              title: BreadcrumbTitle(crumbs: crumbs),
              // Breadcrumb + ⋯ only (UX-LAYOUT §7.3): how the rows under a page
              // are laid out is a choice about those rows, so it sits on their
              // own header below, and a page with none has no such choice.
              actions: [
                // The Nexus root's own ⋮ (Procress 24): its name and the rest
                // of the Nexus's menu two taps from here, not three by way
                // of the Nexus list.
                if (moduleId == null && nexus != null)
                  RowMenuButton(
                    iconSize: 24,
                    title: nexus.name,
                    actions: () => nexusActions(context, ref, nexus, onOwnPage: true),
                  ),
                if (module != null)
                  RowMenuButton(
                    iconSize: 24,
                    title: module.name,
                    // the title's alignment right in the menu (§13): it was
                    // a third tap, through "Title layout…"
                    header: itemKey != null || module.kind != ModuleKind.collector
                        ? PageTitleAlignControl(pageKey: PageKey(module.id, itemKey))
                        : null,
                    actions: () => [
                      ...pageActions(context, ref, module, itemKey),
                      ...moduleRowActions(context, ref, module, onOwnPage: true, itemKey: itemKey, itemName: itemName),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            // Slivers, so a folder's rows build as they scroll in (Procress
            // 19 F5); everything else is one box each, as in a ListView.
            child: CustomScrollView(
              slivers: [
                // The page: a stack of blocks (V5.md §12, APK-V3.md §10.4).
                if (module != null && (itemKey != null || module.kind != ModuleKind.collector))
                  SliverList.list(children: [
                    // The title, laid out as the page says (C6); on iOS the
                    // large title, under the breadcrumb bar (C3).
                    PageHeader(module: module, itemKey: itemKey, title: itemKey != null ? (itemName ?? '') : module.name),
                    ModulePage(moduleId: module.id, itemKey: itemKey),
                  ]),
                // A Collector IS its children, and so is a Nexus root.
                if (itemKey == null && showsChildren(module))
                  ...childrenAsync.when(
                    loading: () => const [
                      SliverToBoxAdapter(
                        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                      ),
                    ],
                    error: (e, s) => [SliverToBoxAdapter(child: Center(child: Text('Error: $e')))],
                    data: (children) {
                      if (children.isEmpty) {
                        return [
                          SliverToBoxAdapter(
                            child: DdxEmptyState(
                              icon: Icons.folder_open_outlined,
                              message: l10n.emptyModuleMessage,
                              actionLabel: l10n.newModuleTooltip,
                              onAction: _newModule,
                            ),
                          ),
                        ];
                      }
                      final shown = ddxSorted(
                        [for (final m in children) if (ddxMatches(_filter, [m.name])) m],
                        _sort,
                        name: (m) => m.name,
                        edited: (m) => m.updatedAt,
                        created: (m) => m.createdAt,
                        kind: (m) => kindName(l10n, m.kind),
                      );
                      return [
                        SliverToBoxAdapter(
                          child: DdxListHeader(
                            count: shown.length,
                            onFilterChanged: (v) => setState(() => _filter = v),
                            sort: _sort,
                            sorts: DdxSort.values,
                            manualOrder: true,
                            onSortChanged: (s) => setState(() => _sort = s),
                            // how the rows are laid out is a choice about
                            // them, so it sits on their header (§7.3)
                            trailing: const [ViewModeButton()],
                          ),
                        ),
                        if (shown.isEmpty)
                          SliverToBoxAdapter(child: DdxEmptyState(icon: Icons.filter_list_off, message: l10n.listNoMatch))
                        else
                          ModuleCollectionView(
                            nexusId: nexusId,
                            modules: shown,
                            mode: viewMode,
                            sliver: true,
                          ),
                      ];
                    },
                  ),
                // A folder's own files, under its sub-folders and modules.
                if (itemKey == null && moduleId != null && module?.kind == ModuleKind.collector)
                  SliverToBoxAdapter(child: FolderAssets(nexusId: nexusId, moduleId: moduleId!)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !selecting
          ? null
          : BottomAppBar(
              child: Row(children: [
                IconButton(tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close), onPressed: endSelect),
                Expanded(child: Text(l10n.selectedCount.replaceAll('{n}', '${selection.length}'))),
                FilledButton.icon(
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: Text(l10n.moveTo),
                  onPressed: () async {
                    final picked = [
                      for (final m in childrenAsync.valueOrNull ?? const <ModuleModel>[])
                        if (selection.contains(m.id)) m,
                    ];
                    await moveModulesWithPicker(context, ref, picked);
                    if (mounted) endSelect();
                  },
                ),
              ]),
            ),
      floatingActionButton: selecting ? null : _fab(context, l10n, module),
    ),
    );
  }
}

/// The page's one main action (UX-LAYOUT §7.1, decided 2026-09-28): on a
/// content page "Edit page", which is Arrange, reading "Done" while
/// arranging; on a Collector or the Nexus root "+", a new module — only a
/// Collector holds modules (v5, APP docs/V5.md §8.8), so anywhere else a new
/// one would have nowhere valid to go.
extension on _ModuleExplorerScreenState {
  Widget? _fab(BuildContext context, AppLocalizations l10n, ModuleModel? module) {
    final contentPage = module != null && (itemKey != null || module.kind != ModuleKind.collector);
    if (contentPage) {
      final key = PageKey(module.id, itemKey);
      final arranging = ref.watch(arrangeModeProvider(key));
      return FloatingActionButton.extended(
        heroTag: 'page-edit',
        onPressed: () => ref.read(arrangeModeProvider(key).notifier).state = !arranging,
        icon: Icon(arranging ? Icons.check : Icons.edit_outlined),
        label: Text(arranging ? l10n.arrangeDone : l10n.editPage),
      );
    }
    if (moduleId != null && module == null) return null; // still loading
    return FloatingActionButton(
      tooltip: l10n.newModuleTooltip,
      onPressed: _newModule,
      child: const Icon(Icons.add),
    );
  }

  /// A new module here — the FAB's action, and the empty folder's one button.
  Future<void> _newModule() async {
    await showNewModuleSheet(context, ref, nexusId, moduleId);
    ref.invalidate(moduleChildrenProvider(_childrenKey));
    ref.invalidate(nexusIndexProvider(nexusId));
  }
}

/// An element page's name, by its family's lookup (ENTITY_KINDS), so every
/// family with a page is named — the Nexus index lists only the ones filters
/// and the Exhibitor show, which leaves out Diviner tables and map pins.
/// Null when the element is gone. Re-read whenever the index is (a rename).
final _itemNameProvider = FutureProvider.autoDispose.family<String?, (int, String)>((ref, arg) async {
  final (nexusId, key) = arg;
  ref.watch(nexusIndexProvider(nexusId));
  final db = await ref.watch(databaseProvider.future);
  return EntityKinds.nameOf(db, key);
});

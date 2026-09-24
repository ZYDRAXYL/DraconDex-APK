import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/models/viewer_model.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/hiding_app_bar.dart';
import '../../widgets/row_menu.dart';
import '../builder/breadcrumb_title.dart';
import '../builder/view_mode_button.dart';
import 'content/module_content.dart';
import 'dialogs/module_dialog.dart';
import 'module_actions.dart';
import 'widgets/module_collection_view.dart';

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

  int get nexusId => widget.nexusId;
  int? get moduleId => widget.moduleId;
  String? get itemKey => widget.itemKey;

  ModuleChildrenKey get _childrenKey => ModuleChildrenKey(nexusId, moduleId);

  /// Opens this screen as a page once whatever it is showing has actually
  /// loaded (a half-resolved '…' title is not worth keeping). Deferred past
  /// the current frame — recording writes provider state, which build() must
  /// not do.
  void _recordOpenPage(NexusModel? nexus, ModuleModel? module, IndexedItem? item) {
    if (nexus == null) return;
    if (moduleId != null && module == null) return;
    if (itemKey != null && item == null) return;

    final view = RecentView(
      nexusId: nexusId,
      moduleId: moduleId,
      itemKey: itemKey,
      title: item?.name ?? module?.name ?? nexus.name,
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
  void _closeIfMissing(AsyncValue<ModuleModel?>? moduleAsync, AsyncValue<List<IndexedItem>>? indexAsync, IndexedItem? item) {
    final moduleGone = moduleId != null && moduleAsync != null && moduleAsync.hasValue && moduleAsync.value == null;
    final itemGone = itemKey != null && indexAsync != null && indexAsync.hasValue && item == null;
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
    final indexAsync = itemKey == null ? null : ref.watch(nexusIndexProvider(nexusId));
    final childrenAsync = ref.watch(moduleChildrenProvider(_childrenKey));

    final module = moduleAsync?.valueOrNull;
    final nexus = nexusAsync.valueOrNull;
    IndexedItem? item;
    for (final it in indexAsync?.valueOrNull ?? const <IndexedItem>[]) {
      if (it.key == itemKey && it.moduleId == moduleId) item = it;
    }
    final viewMode = ref.watch(builderViewModeProvider);

    _recordOpenPage(nexus, module, item);
    _closeIfMissing(moduleAsync, indexAsync, item);

    final crumbs = <Crumb>[
      Crumb(label: nexus?.name ?? '…', nexusId: nexusId),
      for (final a in breadcrumbAsync?.valueOrNull ?? const <ModuleModel>[])
        Crumb(label: a.name, nexusId: nexusId, moduleId: a.id),
      if (moduleId != null) Crumb(label: module?.name ?? '…', nexusId: nexusId, moduleId: moduleId),
      if (itemKey != null) Crumb(label: item?.name ?? '…', nexusId: nexusId, moduleId: moduleId, itemKey: itemKey),
    ];

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HidingAppBar(
            appBar: AppBar(
              title: BreadcrumbTitle(crumbs: crumbs),
              actions: [
                const ViewModeButton(),
                if (module != null)
                  RowMenuButton(
                    iconSize: 24,
                    title: module.name,
                    actions: () => moduleRowActions(context, ref, module, onOwnPage: true),
                  ),
              ],
            ),
          ),
          if (itemKey != null) _ElementPageNotice(text: l10n.elementPageSoon),
          if (module != null) _ModuleContent(module: module),
          Expanded(
            child: childrenAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (children) {
                if (children.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.emptyModuleMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                  );
                }
                return ModuleCollectionView(
                  nexusId: nexusId,
                  modules: children,
                  mode: viewMode,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newModuleTooltip,
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => ModuleDialog(nexusId: nexusId, parentId: moduleId),
          );
          ref.invalidate(moduleChildrenProvider(_childrenKey));
          ref.invalidate(nexusIndexProvider(nexusId));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Stands in for an element's own page until Procress 12 part 2 builds it.
class _ElementPageNotice extends StatelessWidget {
  final String text;

  const _ElementPageNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// The kind-specific content area shown above a module's own children list.
/// Only a few kinds have a real editor so far (§docs/Architec.md §1.1 lists
/// all 15) — everything else falls back to the shared notes field.
class _ModuleContent extends StatelessWidget {
  final ModuleModel module;
  const _ModuleContent({required this.module});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = module.kindInfo;
    final isFolder = module.kind == ModuleKind.collector || module.kind == ModuleKind.manager;
    if (isFolder) return const SizedBox.shrink();

    // Kinds with a real editor render it instead of the shared notes field.
    // moduleContentFor() returns null for the ones not ported yet, which is
    // exactly the set still flagged contentImplemented: false below.
    final dedicated = moduleContentFor(module);
    if (dedicated != null) {
      return Column(
        children: [
          dedicated,
          const Divider(height: 1),
        ],
      );
    }

    return Column(
      children: [
        if (!info.contentImplemented)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.kindContentUnavailable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        // Capped rather than stretched: on an iPad in landscape the pane is
        // wide enough that a full-width note field would run a line of prose
        // past comfortable reading length. A phone is never this wide, so
        // this changes nothing there.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _DescriptionEditor(
              key: ValueKey(module.id),
              moduleId: module.id,
              initialText: module.description ?? '',
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _DescriptionEditor extends ConsumerStatefulWidget {
  final int moduleId;
  final String initialText;
  const _DescriptionEditor({super.key, required this.moduleId, required this.initialText});

  @override
  ConsumerState<_DescriptionEditor> createState() => _DescriptionEditorState();
}

class _DescriptionEditorState extends ConsumerState<_DescriptionEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    if (_dirty) _save();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    final dao = ref.read(moduleDaoProvider).valueOrNull;
    await dao?.updateModuleDescription(widget.moduleId, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.notesHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _dirty = true,
      ),
    );
  }
}

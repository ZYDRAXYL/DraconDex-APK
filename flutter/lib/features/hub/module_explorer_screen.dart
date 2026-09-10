import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/models/recent_view_model.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/recent_views_provider.dart';
import '../../widgets/confirm_dialog.dart';
import 'dialogs/module_dialog.dart';
import 'widgets/module_collection_view.dart';

/// One drill-down level of the Hub explorer, shown inside the Builder shell:
/// the Nexus root (moduleId null) or a single module's own screen — its
/// content area (if its kind has one) plus the modules nested under it.
/// Reused recursively: drilling in pushes this same widget again with a
/// deeper moduleId, file-explorer style.
///
/// Opening one records it in the Builder's folder-views history, which is
/// what the Navibar's folder button lists.
class ModuleExplorerScreen extends ConsumerStatefulWidget {
  final int nexusId;
  final int? moduleId;

  const ModuleExplorerScreen({super.key, required this.nexusId, this.moduleId});

  @override
  ConsumerState<ModuleExplorerScreen> createState() => _ModuleExplorerScreenState();
}

class _ModuleExplorerScreenState extends ConsumerState<ModuleExplorerScreen> {
  /// Last recorded entry, as key+title+color — re-records on a rename or a
  /// recolor so the folder-views list never shows a stale label, but not on
  /// every unrelated rebuild.
  String? _recordedSignature;

  int get nexusId => widget.nexusId;
  int? get moduleId => widget.moduleId;

  ModuleChildrenKey get _childrenKey => ModuleChildrenKey(nexusId, moduleId);

  /// Files this screen into the folder-views history once whatever it is
  /// showing has actually loaded (a half-resolved '…' title is not worth
  /// remembering). Deferred past the current frame — recording writes
  /// provider state, which build() must not do.
  void _recordRecentView(NexusModel? nexus, ModuleModel? module) {
    if (nexus == null) return;
    if (moduleId != null && module == null) return;

    final view = RecentView(
      nexusId: nexusId,
      moduleId: moduleId,
      title: module?.name ?? nexus.name,
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

  /// A folder-views entry can outlive what it points at — the module was
  /// deleted, or it sat under a subtree that was. Landing on one resolves the
  /// module to null (loaded, but absent), which is the moment to drop the
  /// entry so the sheet stops offering the dead jump.
  void _pruneIfMissing(AsyncValue<ModuleModel?>? moduleAsync) {
    if (moduleId == null || moduleAsync == null) return;
    if (!moduleAsync.hasValue || moduleAsync.value != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentViewsProvider.notifier).remove(RecentView.keyFor(nexusId, moduleId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nexusAsync = ref.watch(nexusProvider(nexusId));
    final moduleAsync = moduleId == null ? null : ref.watch(moduleProvider(moduleId!));
    final breadcrumbAsync = moduleId == null ? null : ref.watch(moduleBreadcrumbProvider(moduleId!));
    final childrenAsync = ref.watch(moduleChildrenProvider(_childrenKey));

    final module = moduleAsync?.valueOrNull;
    final nexus = nexusAsync.valueOrNull;
    final title = moduleId == null ? (nexus?.name ?? '…') : (module?.name ?? '…');
    final viewMode = ref.watch(builderViewModeProvider);

    _recordRecentView(nexus, module);
    _pruneIfMissing(moduleAsync);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (module != null) ...[
            IconButton(
              icon: Icon(module.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: module.pinned ? l10n.btnUnpin : l10n.btnPin,
              onPressed: () async {
                await ref.read(moduleDaoProvider).when(
                  data: (d) => d.setPinned(module.id, !module.pinned),
                  loading: () async {},
                  error: (_, _) async {},
                );
                ref.invalidate(moduleProvider(module.id));
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _onModuleAction(context, module, v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.btnRename)),
                PopupMenuItem(value: 'delete', child: Text(l10n.btnDelete)),
              ],
            ),
          ],
        ],
        bottom: moduleId == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: _Breadcrumb(
                  nexusId: nexusId,
                  nexusName: nexus?.name ?? '',
                  ancestors: breadcrumbAsync?.valueOrNull ?? const [],
                ),
              ),
      ),
      body: Column(
        children: [
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
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onModuleAction(BuildContext context, ModuleModel module, String action) async {
    final l10n = AppLocalizations.of(context)!;
    if (action == 'rename') {
      await showDialog(context: context, builder: (_) => ModuleDialog(nexusId: nexusId, existing: module));
      ref.invalidate(moduleProvider(module.id));
      ref.invalidate(moduleChildrenProvider(ModuleChildrenKey(nexusId, module.parentId)));
    } else if (action == 'delete') {
      final ok = await showConfirmDialog(
        context,
        title: '${l10n.confirmDeleteTitle}: "${module.name}"',
        message: l10n.deleteModuleMessage,
      );
      if (!ok) return;
      final parentId = module.parentId;
      await ref.read(moduleDaoProvider).when(
        data: (d) => d.deleteModule(module.id),
        loading: () async {},
        error: (_, _) async {},
      );
      ref.invalidate(moduleChildrenProvider(ModuleChildrenKey(nexusId, parentId)));
      await ref.read(recentViewsProvider.notifier).remove(RecentView.keyFor(nexusId, module.id));
      if (context.mounted) context.pop();
    }
  }
}

class _Breadcrumb extends StatelessWidget {
  final int nexusId;
  final String nexusName;
  final List<ModuleModel> ancestors;

  const _Breadcrumb({required this.nexusId, required this.nexusName, required this.ancestors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = <Widget>[
      _crumb(context, nexusName, () => context.go('/hub/$nexusId')),
    ];
    for (final a in ancestors) {
      crumbs.add(Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)));
      crumbs.add(_crumb(context, a.name, () => context.go('/hub/$nexusId/module/${a.id}')));
    }
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: crumbs),
      ),
    );
  }

  Widget _crumb(BuildContext context, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
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

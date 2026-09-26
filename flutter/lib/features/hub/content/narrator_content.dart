import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/narrator_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../page/views/view_common.dart';

/// Narrator kind: dialogue scenes, the script inside the selected one, and
/// the routes leading out of it.
///
/// The desktop draws this as a node board. A phone is the wrong surface for
/// pan-and-zoom node editing, so the same data is presented as a list: pick a
/// scene, write its lines, and say which scenes it leads to. `pos_x`/`pos_y`
/// are left untouched so the desktop's layout survives editing from here.
class NarratorContent extends ConsumerStatefulWidget {
  final int moduleId;
  /// The module, when the page has it: empty, the kind's empty state
  /// (KindEmptyState) stands in for the list.
  final ModuleModel? module;
  const NarratorContent({super.key, required this.moduleId, this.module});

  @override
  ConsumerState<NarratorContent> createState() => _NarratorContentState();
}

class _NarratorContentState extends ConsumerState<NarratorContent> {
  int? _selectedId;

  Future<String?> _askText(String title, {String initial = ''}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.labelName),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.btnSave),
          ),
        ],
      ),
    );
  }

  Future<void> _addScene() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _askText(l10n.narratorNewScene);
    if (name == null || name.isEmpty) return;
    final dao = ref.read(narratorDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createDialogue(moduleRef: widget.moduleId, name: name);
    if (!mounted) return;
    setState(() => _selectedId = id);
    ref.invalidate(dialoguesProvider(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scenesAsync = ref.watch(dialoguesProvider(widget.moduleId));

    return scenesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (scenes) {
        final selected = scenes.where((d) => d.id == _selectedId).firstOrNull ??
            (scenes.isEmpty ? null : scenes.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(l10n.narratorScenes, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addScene,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.narratorNewScene),
                  ),
                ],
              ),
            ),
            if (scenes.isEmpty && widget.module != null)
              KindEmptyState(module: widget.module!, note: l10n.narratorNoScenes, startLabel: l10n.narratorNewScene, onStart: _addScene)
            else if (scenes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.narratorNoScenes, style: theme.textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: scenes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final d = scenes[i];
                    return ChoiceChip(
                      label: Text(d.name, overflow: TextOverflow.ellipsis),
                      selected: selected?.id == d.id,
                      onSelected: (_) => setState(() => _selectedId = d.id),
                    );
                  },
                ),
              ),
              if (selected != null)
                _Scene(
                  key: ValueKey(selected.id),
                  moduleId: widget.moduleId,
                  scene: selected,
                  allScenes: scenes,
                  onDeleted: () => setState(() => _selectedId = null),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Scene extends ConsumerWidget {
  final int moduleId;
  final DialogueModel scene;
  final List<DialogueModel> allScenes;
  final VoidCallback onDeleted;

  const _Scene({
    super.key,
    required this.moduleId,
    required this.scene,
    required this.allScenes,
    required this.onDeleted,
  });

  Future<void> _addLine(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final speaker = TextEditingController();
    final sentence = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.narratorNewLine),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: speaker,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.narratorSpeaker),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sentence,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.narratorLine,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.btnSave)),
        ],
      ),
    );
    if (ok != true) return;
    final dao = ref.read(narratorDaoProvider).valueOrNull;
    await dao?.addTalk(
      dialogueRef: scene.id,
      speaker: speaker.text.trim().isEmpty ? null : speaker.text.trim(),
      sentence: sentence.text.trim().isEmpty ? null : sentence.text.trim(),
    );
    ref.invalidate(talksProvider(scene.id));
  }

  Future<void> _addRoute(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final others = allScenes.where((d) => d.id != scene.id).toList();
    if (others.isEmpty) return;
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.narratorLeadsTo),
        children: [
          for (final d in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(d.id),
              child: Text(d.name),
            ),
        ],
      ),
    );
    if (target == null) return;
    final dao = ref.read(narratorDaoProvider).valueOrNull;
    await dao?.addEdge(moduleRef: moduleId, fromRef: scene.id, toRef: target);
    ref.invalidate(storyEdgesProvider(scene.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final talksAsync = ref.watch(talksProvider(scene.id));
    final edgesAsync = ref.watch(storyEdgesProvider(scene.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(scene.name,
                    style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: l10n.btnDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: l10n.confirmDeleteTitle,
                    message: l10n.confirmDeleteMessage,
                  );
                  if (!ok) return;
                  final dao = ref.read(narratorDaoProvider).valueOrNull;
                  await dao?.deleteDialogue(scene.id);
                  onDeleted();
                  ref.invalidate(dialoguesProvider(moduleId));
                },
              ),
            ],
          ),
          // ---- script ----------------------------------------------
          Row(
            children: [
              Text(l10n.narratorScript, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addLine(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.narratorNewLine),
              ),
            ],
          ),
          talksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (talks) => talks.isEmpty
                ? Text(l10n.narratorNoLines, style: theme.textTheme.bodySmall)
                : Column(
                    children: [
                      for (final t in talks)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            t.speaker?.isNotEmpty == true ? t.speaker! : '—',
                            style: theme.textTheme.labelMedium,
                          ),
                          subtitle: Text(t.sentence ?? ''),
                          // Non-talk rows are authored on the desktop; show
                          // them but do not offer to edit them as talk.
                          trailing: t.isPlainTalk
                              ? IconButton(
                                  tooltip: l10n.btnDelete,
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () async {
                                    final dao = ref.read(narratorDaoProvider).valueOrNull;
                                    await dao?.deleteTalk(t.id);
                                    ref.invalidate(talksProvider(scene.id));
                                  },
                                )
                              : Chip(
                                  label: Text(t.rowType,
                                      style: theme.textTheme.labelSmall),
                                  visualDensity: VisualDensity.compact,
                                ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 20),
          // ---- routes ----------------------------------------------
          Row(
            children: [
              Text(l10n.narratorRoutes, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: allScenes.length < 2 ? null : () => _addRoute(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.narratorLeadsTo),
              ),
            ],
          ),
          edgesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, s) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (edges) => edges.isEmpty
                ? Text(l10n.narratorNoRoutes, style: theme.textTheme.bodySmall)
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in edges)
                        InputChip(
                          label: Text(e.toName),
                          avatar: const Icon(Icons.arrow_forward, size: 16),
                          onDeleted: () async {
                            final dao = ref.read(narratorDaoProvider).valueOrNull;
                            await dao?.deleteEdge(e.id);
                            ref.invalidate(storyEdgesProvider(scene.id));
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

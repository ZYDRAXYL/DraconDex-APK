import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/narrator/story_logic.dart';
import '../../../data/dao/narrator_dao.dart';
import '../../../data/models/narrator_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/row_menu.dart';
import '../../hub/content/narrator_content.dart';
import '../component_registry.dart';
import 'graph_view.dart';
import 'node_canvas.dart';
import 'view_common.dart';

/// The Narrator's four presets (EXE mod/narrator.js NARRATOR_VIEWS): board,
/// routes, reader (script and play-test, narrator-logic.js), dialogue.

class StoryEdge {
  final int id;
  final int from;
  final int to;
  final String? label;
  const StoryEdge(this.id, this.from, this.to, this.label);
}

class StoryOption {
  final int id;
  final int talk;
  final String text;
  final String effectKind;
  final String? effectText;
  final int? jump;
  final String? condition;
  final String? setOps;
  const StoryOption(this.id, this.talk, this.text, this.effectKind, this.effectText, this.jump, this.condition, this.setOps);
}

class StoryData {
  final List<DialogueModel> dialogues;
  final List<StoryEdge> edges;
  final Map<int, List<TalkModel>> talks;
  final Map<int, List<StoryOption>> options; // by talk
  const StoryData(this.dialogues, this.edges, this.talks, this.options);

  String nameOf(int id) => dialogues.where((d) => d.id == id).firstOrNull?.name ?? '—';

  /// Scenes in reading order: from each root (nothing leads to it), depth
  /// first along the routes; anything unreachable after (EXE
  /// mountNarratorReader).
  List<int> readingOrder() {
    final inDeg = {for (final e in edges) e.to};
    final roots = [for (final d in dialogues) if (!inDeg.contains(d.id)) d.id];
    final order = <int>[];
    final seen = <int>{};
    void visit(int id) {
      if (!seen.add(id)) return;
      order.add(id);
      for (final e in edges) {
        if (e.from == id) visit(e.to);
      }
    }

    for (final r in roots.isEmpty ? [for (final d in dialogues) d.id] : roots) {
      visit(r);
    }
    for (final d in dialogues) {
      visit(d.id);
    }
    return order;
  }
}

final storyDataProvider = FutureProvider.autoDispose.family<StoryData, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final dialogues = await NarratorDao(db).getDialogues(moduleId);
  final edges = await db.rawQuery('SELECT id, from_ref, to_ref, label FROM story_edge WHERE module_ref=? ORDER BY id', [moduleId]);
  final talks = await db.rawQuery(
      'SELECT t.* FROM story_talk t JOIN story_dialogue d ON t.dialogue_ref=d.id WHERE d.module_ref=? ORDER BY t.talk_order, t.id',
      [moduleId]);
  final opts = await db.rawQuery(
      'SELECT o.* FROM story_choice_option o JOIN story_talk t ON o.talk_ref=t.id JOIN story_dialogue d ON t.dialogue_ref=d.id '
      'WHERE d.module_ref=? ORDER BY o.option_order, o.id',
      [moduleId]);
  final byDialogue = <int, List<TalkModel>>{};
  for (final t in talks) {
    final m = TalkModel.fromMap(t);
    (byDialogue[m.dialogueRef] ??= []).add(m);
  }
  final byTalk = <int, List<StoryOption>>{};
  for (final o in opts) {
    (byTalk[o['talk_ref'] as int] ??= []).add(StoryOption(
      o['id'] as int,
      o['talk_ref'] as int,
      o['option_text'] as String? ?? '',
      o['effect_kind'] as String? ?? 'none',
      o['effect_text'] as String?,
      o['jump_ref'] as int?,
      o['condition'] as String?,
      o['set_ops'] as String?,
    ));
  }
  return StoryData(
    dialogues,
    [
      for (final e in edges) StoryEdge(e['id'] as int, e['from_ref'] as int, e['to_ref'] as int, e['label'] as String?),
    ],
    byDialogue,
    byTalk,
  );
});

void _refresh(WidgetRef ref, int moduleId) {
  ref.invalidate(storyDataProvider(moduleId));
  ref.invalidate(dialoguesProvider(moduleId));
}

class NarratorView extends ConsumerWidget {
  final ComponentCtx ctx;
  const NarratorView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final id = ctx.source.id;
    if (ctx.preset == 'dialogue') return NarratorContent(moduleId: id);
    final data = ref.watch(storyDataProvider(id)).valueOrNull;
    if (data == null) return const SizedBox(height: 48);
    final bar = ViewBar(actions: [
      if (ctx.preset == 'routes' || ctx.preset == 'board')
        IconButton(
          tooltip: l.narAddRoute,
          icon: const Icon(Icons.alt_route),
          onPressed: data.dialogues.length < 2 ? null : () => _addRoute(context, ref, id, data),
        ),
      IconButton(
        tooltip: l.narratorNewScene,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final name = await askText(context, l.narratorNewScene, label: l.labelName);
          if (name == null) return;
          final db = await ref.read(databaseProvider.future);
          final nid = await NarratorDao(db).createDialogue(moduleRef: id, name: name);
          // Beside the rightmost scene, so a new one never lands on another.
          final right = data.dialogues.fold<double>(-220, (m, d) => math.max(m, d.posX));
          await db.rawUpdate('UPDATE story_dialogue SET pos_x=?, pos_y=? WHERE id=?', [right + 220, 0, nid]);
          _refresh(ref, id);
          ref.invalidate(nexusIndexProvider(ctx.nexusId));
        },
      ),
    ]);
    if (data.dialogues.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, EmptyHint(l.narratorNoScenes)]);
    }
    final body = switch (ctx.preset) {
      'routes' => _Routes(ctx: ctx, data: data),
      'reader' => _Reader(ctx: ctx, data: data),
      _ => _Board(ctx: ctx, data: data),
    };
    if (ctx.fullScreen) return Column(children: [if (ctx.preset != 'board') bar, Expanded(child: body)]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, body]);
  }
}

Future<void> _addRoute(BuildContext context, WidgetRef ref, int moduleId, StoryData data, {int? from}) async {
  final l = AppLocalizations.of(context)!;
  int? to;
  final label = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setLocal) {
        DropdownButtonFormField<int> pick(int? v, String hint, void Function(int?) set) => DropdownButtonFormField<int>(
              initialValue: v,
              isExpanded: true,
              decoration: InputDecoration(labelText: hint),
              items: [for (final s in data.dialogues) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
              onChanged: (x) => setLocal(() => set(x)),
            );
        return AlertDialog(
          title: Text(l.narAddRoute),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            pick(from, l.connectorFrom, (x) => from = x),
            pick(to, l.narratorLeadsTo, (x) => to = x),
            TextField(controller: label, decoration: InputDecoration(labelText: l.connectorLabel)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
          ],
        );
      },
    ),
  );
  final text = label.text.trim();
  label.dispose();
  if (ok != true || from == null || to == null || from == to) return;
  final db = await ref.read(databaseProvider.future);
  await NarratorDao(db).addEdge(moduleRef: moduleId, fromRef: from!, toRef: to!, label: text.isEmpty ? null : text);
  _refresh(ref, moduleId);
}

/// Scenes on the route board, where the desktop put them.
class _Board extends ConsumerWidget {
  final ComponentCtx ctx;
  final StoryData data;
  const _Board({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final id = ctx.source.id;
    // Scenes a phone made before the board existed all sit at 0,0: fan them
    // out for drawing (they are saved only when dragged).
    final seen = <Offset>{};
    var spill = 0;
    Offset place(DialogueModel d) {
      var p = Offset(d.posX, d.posY);
      if (!seen.add(p)) {
        spill++;
        p = Offset(p.dx + 200.0 * (spill % 4), p.dy + 110.0 * (spill ~/ 4 + 1));
        seen.add(p);
      }
      return p;
    }

    return NodeCanvas(
      fullScreen: ctx.fullScreen,
      nodes: [
        for (final d in data.dialogues)
          CanvasNode(
            d.id,
            place(d),
            const Size(170, 64),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(left: BorderSide(color: hexColor(d.colorCode) ?? theme.colorScheme.primary, width: 4)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.12), blurRadius: 4)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                Text(
                  '${data.talks[d.id]?.length ?? 0} · ${data.edges.where((e) => e.from == d.id).length} →',
                  style: theme.textTheme.labelSmall,
                ),
              ]),
            ),
          ),
      ],
      links: [for (final e in data.edges) CanvasLink(e.from, e.to, label: e.label)],
      onTap: (did) => openElement(context, ctx.nexusId, id, 'sdlg_$did'),
      onLongPress: (did) {
        final d = data.dialogues.firstWhere((x) => x.id == did);
        showRowMenu(context, title: d.name, [
          RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => openElement(context, ctx.nexusId, id, 'sdlg_$did')),
          RowAction(label: l.narAddRoute, icon: Icons.alt_route, onTap: () => _addRoute(context, ref, id, data, from: did)),
          RowAction(
            label: l.btnDelete,
            icon: Icons.delete_outline,
            danger: true,
            onTap: () async {
              if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
              final db = await ref.read(databaseProvider.future);
              await NarratorDao(db).deleteDialogue(did);
              _refresh(ref, id);
              ref.invalidate(nexusIndexProvider(ctx.nexusId));
            },
          ),
        ]);
      },
      onMoved: (did, p) async {
        final db = await ref.read(databaseProvider.future);
        await db.rawUpdate("UPDATE story_dialogue SET pos_x=?, pos_y=?, update_at=datetime('now') WHERE id=?", [p.dx, p.dy, did]);
        _refresh(ref, id);
      },
    );
  }
}

class _Routes extends ConsumerWidget {
  final ComponentCtx ctx;
  final StoryData data;
  const _Routes({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (data.edges.isEmpty) return EmptyHint(l.narratorNoRoutes);
    return Column(children: [
      for (final e in data.edges)
        ListTile(
          dense: true,
          title: Text('${data.nameOf(e.from)}  →  ${data.nameOf(e.to)}'),
          subtitle: e.label?.isNotEmpty == true ? Text(e.label!) : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: l.btnDelete,
            onPressed: () async {
              final db = await ref.read(databaseProvider.future);
              await NarratorDao(db).deleteEdge(e.id);
              _refresh(ref, ctx.source.id);
            },
          ),
        ),
    ]);
  }
}

/// The script read top to bottom, or played through (play-test): options
/// whose condition fails are hidden, set-ops change the variables, nothing
/// is written back.
class _Reader extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  final StoryData data;
  const _Reader({required this.ctx, required this.data});

  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

class _PlayLine {
  final String kind; // head | line | pick | note
  final String text;
  final String? speaker;
  const _PlayLine(this.kind, this.text, [this.speaker]);
}

class _ReaderState extends ConsumerState<_Reader> {
  bool _play = false;
  bool _showHidden = false;
  Map<String, StoryVar> _vars = {};
  final Set<String> _changed = {};
  final List<_PlayLine> _log = [];
  int? _scene;
  int _idx = 0;
  ({String kind, TalkModel? talk, List<StoryEdge> outs})? _pending;

  StoryData get d => widget.data;

  Future<void> _start() async {
    final db = await ref.read(databaseProvider.future);
    final vars = await StoryLogic.variables(db, widget.ctx.nexusId);
    final inDeg = {for (final e in d.edges) e.to};
    setState(() {
      _vars = vars;
      _changed.clear();
      _log.clear();
      _scene = d.dialogues.where((x) => !inDeg.contains(x.id)).firstOrNull?.id ?? d.dialogues.first.id;
      _idx = 0;
      _pending = null;
    });
    _advance();
  }

  /// Reads lines until a choice or the end of the scene.
  void _advance() {
    final scene = _scene;
    if (scene == null) return;
    final talks = d.talks[scene] ?? const [];
    setState(() {
      if (_idx == 0) _log.add(_PlayLine('head', d.nameOf(scene)));
      while (_idx < talks.length && _log.length < 500) {
        final t = talks[_idx];
        if (t.rowType == 'choice') {
          _pending = (kind: 'choice', talk: t, outs: const []);
          return;
        }
        _log.add(_PlayLine('line', t.sentence ?? '', t.speaker));
        _idx++;
      }
      final outs = [for (final e in d.edges) if (e.from == scene) e];
      _pending = (kind: outs.isEmpty ? 'end' : 'route', talk: null, outs: outs);
    });
  }

  void _pick(StoryOption o) {
    final before = {for (final v in _vars.values) v.key: v.value};
    setState(() {
      _log.add(_PlayLine('pick', o.text));
      StoryLogic.apply(StoryLogic.parse(o.setOps), _vars);
      for (final v in _vars.values) {
        if (before[v.key] != v.value) _changed.add(v.key);
      }
      if (o.effectKind == 'text' && (o.effectText ?? '').isNotEmpty) _log.add(_PlayLine('note', o.effectText!));
      if (o.effectKind == 'reply' && (o.effectText ?? '').isNotEmpty) _log.add(_PlayLine('line', o.effectText!));
      _pending = null;
      if (o.effectKind == 'jump' && o.jump != null) {
        _scene = o.jump;
        _idx = 0;
      } else {
        _idx++;
      }
    });
    _advance();
  }

  void _follow(int to) {
    setState(() {
      _pending = null;
      _scene = to;
      _idx = 0;
    });
    _advance();
  }

  void _showVars() {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: _vars.isEmpty
            ? Padding(padding: const EdgeInsets.all(20), child: Text(l.narNoVariables))
            : ListView(shrinkWrap: true, children: [
                for (final v in _vars.values)
                  ListTile(
                    dense: true,
                    title: Text(v.name),
                    trailing: Text(v.text,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _changed.contains(v.key) ? Theme.of(s).colorScheme.primary : null,
                        )),
                  ),
              ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mode = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.narScript), icon: const Icon(Icons.menu_book_outlined)),
            ButtonSegment(value: true, label: Text(l.narPlayTest), icon: const Icon(Icons.play_arrow)),
          ],
          selected: {_play},
          onSelectionChanged: (s) {
            setState(() => _play = s.first);
            if (_play) _start();
          },
        ),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      mode,
      if (_play) _playBody(l) else _script(l),
    ]);
  }

  Widget _line(String? speaker, String text, {bool ghost = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(children: [
          if (speaker?.isNotEmpty == true) TextSpan(text: '$speaker: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: text),
        ]),
        style: ghost ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor) : theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _script(AppLocalizations l) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final id in d.readingOrder())
          if (d.dialogues.where((x) => x.id == id).firstOrNull case final DialogueModel dl)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: hexColor(dl.colorCode) ?? theme.colorScheme.primary, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dl.name, style: theme.textTheme.titleSmall?.copyWith(color: hexColor(dl.colorCode) ?? theme.colorScheme.primary)),
                for (final t in d.talks[id] ?? const <TalkModel>[])
                  if (t.rowType != 'choice')
                    _line(t.speaker, t.sentence ?? '')
                  else ...[
                    if (t.sentence?.isNotEmpty == true) _line(null, t.sentence!),
                    for (final o in d.options[t.id] ?? const <StoryOption>[])
                      _line(null,
                          '▸ ${o.text}${o.effectKind == 'jump' ? '  → ${d.nameOf(o.jump ?? -1)}' : (o.effectKind == 'none' ? '' : '  ${o.effectText ?? ''}')}'),
                  ],
                if ((d.talks[id] ?? const []).isEmpty) _line(null, '—', ghost: true),
                for (final e in d.edges)
                  if (e.from == id) _line(null, '→ ${e.label?.isNotEmpty == true ? e.label! : d.nameOf(e.to)}', ghost: true),
              ]),
            ),
      ]),
    );
  }

  Widget _playBody(AppLocalizations l) {
    final theme = Theme.of(context);
    final p = _pending;
    final next = <Widget>[];
    if (p?.kind == 'choice') {
      if (p!.talk!.sentence?.isNotEmpty == true) next.add(_line(null, p.talk!.sentence!));
      var any = false;
      for (final o in d.options[p.talk!.id] ?? const <StoryOption>[]) {
        final ok = StoryLogic.holds(StoryLogic.parse(o.condition), _vars);
        if (!ok && !_showHidden) continue;
        any = true;
        next.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton(
            onPressed: ok ? () => _pick(o) : null,
            child: Text(ok ? (o.text.isEmpty ? '…' : o.text) : '${o.text} (${l.narHiddenByCondition})'),
          ),
        ));
      }
      if (!any) next.add(_line(null, l.narNoOptionOpen, ghost: true));
    } else if (p?.kind == 'route') {
      for (final e in p!.outs) {
        next.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton(
            onPressed: () => _follow(e.to),
            child: Text('→ ${e.label?.isNotEmpty == true ? e.label! : d.nameOf(e.to)}'),
          ),
        ));
      }
    } else if (p?.kind == 'end') {
      next.add(_line(null, l.narPlayEnd, ghost: true));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton.icon(onPressed: _start, icon: const Icon(Icons.replay, size: 18), label: Text(l.narRestart)),
          TextButton.icon(
            onPressed: _showVars,
            icon: Badge(isLabelVisible: _changed.isNotEmpty, label: Text('${_changed.length}'), child: const Icon(Icons.tune, size: 18)),
            label: Text('${l.narVariables} (${_vars.length})'),
          ),
          FilterChip(label: Text(l.narShowHidden), selected: _showHidden, onSelected: (v) => setState(() => _showHidden = v)),
        ]),
        const Divider(),
        for (final line in _log)
          switch (line.kind) {
            'head' => Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(line.text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
            'pick' => _line(null, '▸ ${line.text}'),
            'note' => _line(null, line.text, ghost: true),
            _ => _line(line.speaker, line.text),
          },
        ...next,
        const SizedBox(height: 8),
      ]),
    );
  }
}

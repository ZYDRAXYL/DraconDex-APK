import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/author_dao.dart';
import '../../../data/models/author_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/markdown_view.dart';
import '../../../widgets/row_menu.dart';
import '../../hub/content/author_content.dart';
import '../component_registry.dart';
import '../core_components.dart';
import 'view_common.dart';

/// The Author's five presets (EXE mod/author.js AUTHOR_VIEWS): editor,
/// board (the corkboard, author-board.js), outline, reading, book.

const authorStatuses = ['idea', 'draft', 'revised', 'done'];

String authorStatusLabel(AppLocalizations l, String s) => switch (s) {
      'idea' => l.auStatusIdea,
      'draft' => l.auStatusDraft,
      'revised' => l.auStatusRevised,
      'done' => l.auStatusDone,
      _ => '—',
    };

/// A chapter saved by the desktop's rich editor is HTML (EXE
/// authorLooksHtml); this shows it as text rather than as tags.
String chapterText(String? content) {
  final c = content ?? '';
  if (!RegExp(r'^\s*<').hasMatch(c)) return c;
  return c
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&emsp;', '    ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class AuthorView extends ConsumerWidget {
  final ComponentCtx ctx;
  const AuthorView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final id = ctx.source.id;
    if (ctx.preset == 'editor' || ctx.preset.isEmpty) return AuthorContent(moduleId: id, module: ctx.source);
    final chapters = ref.watch(chaptersProvider(id)).valueOrNull;
    if (chapters == null) return const SizedBox(height: 48);
    Future<void> add() async {
      final name = await askText(context, l.authorNewChapter, label: l.labelName);
      if (name == null) return;
      final db = await ref.read(databaseProvider.future);
      await AuthorDao(db).createChapter(moduleRef: id, name: name);
      ref.invalidate(chaptersProvider(id));
      ref.invalidate(nexusIndexProvider(ctx.nexusId));
    }

    final bar = ViewBar(actions: [
      IconButton(tooltip: l.authorNewChapter, icon: const Icon(Icons.add), onPressed: add),
    ]);
    if (chapters.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, KindEmptyState(module: ctx.source, note: l.authorNoChapters, startLabel: l.authorNewChapter, onStart: add)]);
    final body = switch (ctx.preset) {
      'board' => _Board(ctx: ctx, chapters: chapters),
      'outline' => _Outline(ctx: ctx, chapters: chapters),
      'book' => _Book(ctx: ctx, chapters: chapters),
      _ => _Reading(ctx: ctx, chapters: chapters),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, body]);
  }
}

String _no(ChapterModel c, int i) => c.label?.isNotEmpty == true ? c.label! : '${i + 1}';

void _chapterMenu(BuildContext context, WidgetRef ref, ComponentCtx ctx, ChapterModel c) {
  final l = AppLocalizations.of(context)!;
  Future<AuthorDao> dao() async => AuthorDao(await ref.read(databaseProvider.future));
  void done() => ref.invalidate(chaptersProvider(ctx.source.id));
  showRowMenu(context, title: c.name, [
    RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'bchp_${c.id}')),
    RowAction(
      label: l.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        final name = await askText(context, l.btnRename, initial: c.name, label: l.labelName);
        if (name == null) return;
        await (await dao()).renameChapter(c.id, name, label: c.label);
        done();
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
    RowAction(
      label: l.auPov,
      icon: Icons.person_outline,
      onTap: () async {
        final it = await pickEntity(context, ref, ctx.nexusId, title: l.auPov);
        if (it == null) return;
        await (await dao()).setChapterMeta(c.id, povKey: it.key);
        done();
      },
    ),
    if (c.povKey != null)
      RowAction(
        label: '${l.auPov} · ${l.btnClear}',
        icon: Icons.person_off_outlined,
        onTap: () async {
          await (await dao()).setChapterMeta(c.id, clearPov: true);
          done();
        },
      ),
    RowAction(
      label: l.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () async {
        if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
        await (await dao()).deleteChapter(c.id);
        done();
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
  ]);
}

/// The corkboard: every chapter an index card with its synopsis, status and
/// point of view (EXE buildAuthorBoardHtml).
class _Board extends ConsumerWidget {
  final ComponentCtx ctx;
  final List<ChapterModel> chapters;
  const _Board({required this.ctx, required this.chapters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final names = {for (final it in ref.watch(nexusIndexProvider(ctx.nexusId)).valueOrNull ?? const []) it.key: it.name};
    final counts = [
      for (final s in authorStatuses)
        if (chapters.where((c) => c.status == s).length case final n when n > 0) (s, n),
    ];
    Future<void> meta(ChapterModel c, {String? synopsis, String? status}) async {
      final db = await ref.read(databaseProvider.future);
      await AuthorDao(db).setChapterMeta(c.id, synopsis: synopsis, status: status);
      ref.invalidate(chaptersProvider(ctx.source.id));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (counts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, children: [
            for (final (s, n) in counts) Chip(visualDensity: VisualDensity.compact, label: Text('${authorStatusLabel(l, s)} $n')),
          ]),
        ),
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 170,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        children: [
          for (var i = 0; i < chapters.length; i++)
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'bchp_${chapters[i].id}'),
                onLongPress: () => _chapterMenu(context, ref, ctx, chapters[i]),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(_no(chapters[i], i), style: theme.textTheme.labelSmall),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(chapters[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final v = await editTextSheet(context,
                              title: l.auSynopsis, initial: chapters[i].synopsis ?? '', nexusId: ctx.nexusId);
                          if (v != null) await meta(chapters[i], synopsis: v);
                        },
                        child: Text(
                          chapters[i].synopsis?.isNotEmpty == true ? chapters[i].synopsis! : l.auSynopsis,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: chapters[i].synopsis?.isNotEmpty == true
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ),
                    ),
                    Row(children: [
                      DropdownButton<String>(
                        value: authorStatuses.contains(chapters[i].status) ? chapters[i].status : '',
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: theme.textTheme.labelSmall,
                        items: [
                          for (final s in ['', ...authorStatuses]) DropdownMenuItem(value: s, child: Text(authorStatusLabel(l, s))),
                        ],
                        onChanged: (s) => meta(chapters[i], status: s ?? ''),
                      ),
                      const Spacer(),
                      if (chapters[i].povKey != null) ...[
                        const Icon(Icons.person_outline, size: 14),
                        Flexible(
                          child: Text(names[chapters[i].povKey] ?? '', overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}

/// Chapters in order with their synopses; drag to reorder.
class _Outline extends ConsumerWidget {
  final ComponentCtx ctx;
  final List<ChapterModel> chapters;
  const _Outline({required this.ctx, required this.chapters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) async {
        final ids = [for (final c in chapters) c.id];
        ids.insert(to, ids.removeAt(from));
        final db = await ref.read(databaseProvider.future);
        await AuthorDao(db).reorderChapters(ids);
        ref.invalidate(chaptersProvider(ctx.source.id));
      },
      children: [
        for (var i = 0; i < chapters.length; i++)
          ListTile(
            key: ValueKey(chapters[i].id),
            leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
            title: Text('${_no(chapters[i], i)}. ${chapters[i].name}'),
            subtitle: chapters[i].synopsis?.isNotEmpty == true
                ? Text(chapters[i].synopsis!, maxLines: 2, overflow: TextOverflow.ellipsis)
                : null,
            trailing: chapters[i].status == null ? null : Text(authorStatusLabel(AppLocalizations.of(context)!, chapters[i].status!)),
            onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'bchp_${chapters[i].id}'),
            onLongPress: () => _chapterMenu(context, ref, ctx, chapters[i]),
          ),
      ],
    );
  }
}

/// Every chapter one after the other, as a reader sees the book.
class _Reading extends StatelessWidget {
  final ComponentCtx ctx;
  final List<ChapterModel> chapters;
  const _Reading({required this.ctx, required this.chapters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < chapters.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text('${_no(chapters[i], i)}. ${chapters[i].name}', style: theme.textTheme.titleLarge),
          ),
          MarkdownView(
            text: chapterText(chapters[i].content),
            nexusId: ctx.nexusId,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ]),
    );
  }
}

/// One chapter at a time, with a jump list and previous/next.
class _Book extends StatefulWidget {
  final ComponentCtx ctx;
  final List<ChapterModel> chapters;
  const _Book({required this.ctx, required this.chapters});

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final cs = widget.chapters;
    final i = _i.clamp(0, cs.length - 1);
    final c = cs[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButton<int>(
          value: i,
          isExpanded: true,
          items: [for (var k = 0; k < cs.length; k++) DropdownMenuItem(value: k, child: Text('${_no(cs[k], k)}. ${cs[k].name}'))],
          onChanged: (v) => setState(() => _i = v ?? 0),
        ),
        const SizedBox(height: 12),
        Text(c.name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        MarkdownView(text: chapterText(c.content), nexusId: widget.ctx.nexusId, style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
        const SizedBox(height: 16),
        // Flexible labels: "Precedente"/"Попередній" do not fit a phone
        // row at full length next to the counter.
        Row(children: [
          Flexible(
            child: TextButton.icon(
              onPressed: i > 0 ? () => setState(() => _i = i - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(l.btnPrevious, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${i + 1} / ${cs.length}', style: theme.textTheme.labelSmall),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: i < cs.length - 1 ? () => setState(() => _i = i + 1) : null,
                icon: const Icon(Icons.chevron_right),
                label: Text(l.btnNext, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

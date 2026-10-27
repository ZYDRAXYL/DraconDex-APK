import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/author_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../page/views/view_common.dart';
import '../../../widgets/ddx_chip.dart';
import '../../../widgets/ddx_icon_button.dart';
import '../../../widgets/ddx_field.dart';
import '../../../widgets/row_menu.dart';
import '../../page/views/author_parts.dart';
import '../../page/views/author_views.dart' show authorStatuses, authorStatusLabel;

/// Author kind: a book made of chapters. The chapter list picks one; the
/// editor below writes `book_chapter.chapter_content`.
///
/// Editing follows _DescriptionEditor's contract in module_explorer_screen —
/// save on blur and on dispose rather than on every keystroke, so a long
/// chapter is not one database write per character.
class AuthorContent extends ConsumerStatefulWidget {
  final int moduleId;
  /// The module, when the page has it: empty, the kind's empty state
  /// (KindEmptyState) stands in for the list.
  final ModuleModel? module;
  const AuthorContent({super.key, required this.moduleId, this.module});

  @override
  ConsumerState<AuthorContent> createState() => _AuthorContentState();
}

class _AuthorContentState extends ConsumerState<AuthorContent> {
  int? _selectedId;

  Future<void> _addChapter() async {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.read(authorDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createChapter(moduleRef: widget.moduleId, name: l10n.authorNewChapter);
    if (!mounted) return;
    setState(() => _selectedId = id);
    ref.invalidate(chaptersProvider(widget.moduleId));
  }

  Future<void> _delete(ChapterModel c) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.confirmDeleteMessage,
    );
    if (!ok) return;
    final dao = ref.read(authorDaoProvider).valueOrNull;
    final chapters = ref.read(chaptersProvider(widget.moduleId)).valueOrNull ?? const <ChapterModel>[];
    final at = chapters.indexWhere((x) => x.id == c.id);
    await dao?.deleteChapter(c.id);
    // the Part dividers after it close up (Procress 28 part 5)
    final parts = ref.read(authorPartsProvider(widget.moduleId)).valueOrNull ?? const <AuthorPart>[];
    if (at >= 0 && parts.isNotEmpty) await saveAuthorParts(ref, widget.moduleId, partsAfterDelete(parts, at));
    if (!mounted) return;
    if (_selectedId == c.id) setState(() => _selectedId = null);
    ref.invalidate(chaptersProvider(widget.moduleId));
  }

  // "+ Part divider": after the open chapter (or at the end), named at once.
  Future<void> _addPart(List<ChapterModel> chapters, ChapterModel? selected) async {
    final parts = ref.read(authorPartsProvider(widget.moduleId)).valueOrNull ?? const <AuthorPart>[];
    final i = selected == null ? -1 : chapters.indexOf(selected);
    final p = AuthorPart(newAuthorPartId(), i < 0 ? chapters.length : i + 1);
    await saveAuthorParts(ref, widget.moduleId, [...parts, p]);
    if (mounted) await _renamePart(p);
  }

  Future<void> _renamePart(AuthorPart p) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await askText(context, l10n.auPart, initial: p.label, label: l10n.auPartPlaceholder, allowEmpty: true);
    if (name == null) return;
    final parts = ref.read(authorPartsProvider(widget.moduleId)).valueOrNull ?? const <AuthorPart>[];
    await saveAuthorParts(ref, widget.moduleId, [for (final x in parts) x.id == p.id ? x.copyWith(label: name.trim()) : x]);
  }

  // A part's menu: name it, move it a chapter earlier / later, delete it —
  // a phone's stand-in for the desktop's drag.
  void _partMenu(AuthorPart p, int chapterCount) {
    final l10n = AppLocalizations.of(context)!;
    Future<void> set(List<AuthorPart> Function(List<AuthorPart>) f) async {
      final parts = ref.read(authorPartsProvider(widget.moduleId)).valueOrNull ?? const <AuthorPart>[];
      await saveAuthorParts(ref, widget.moduleId, f(parts));
    }

    showRowMenu(context, title: p.label.isEmpty ? l10n.auPart : p.label, [
      RowAction(label: l10n.btnRename, icon: Icons.edit_outlined, onTap: () => _renamePart(p)),
      if (p.at > 0)
        RowAction(label: l10n.btnPrevious, icon: Icons.chevron_left, onTap: () => set((ps) => [for (final x in ps) x.id == p.id ? x.copyWith(at: x.at - 1) : x])),
      if (p.at < chapterCount)
        RowAction(label: l10n.btnNext, icon: Icons.chevron_right, onTap: () => set((ps) => [for (final x in ps) x.id == p.id ? x.copyWith(at: x.at + 1) : x])),
      RowAction(label: l10n.btnDelete, icon: Icons.delete_outline, danger: true, onTap: () => set((ps) => [for (final x in ps) if (x.id != p.id) x])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersProvider(widget.moduleId));
    final parts = ref.watch(authorPartsProvider(widget.moduleId)).valueOrNull ?? const <AuthorPart>[];

    return chaptersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (chapters) {
        // A chapter deleted elsewhere must not leave a dangling selection.
        final selected = chapters.where((c) => c.id == _selectedId).firstOrNull ??
            (chapters.isEmpty ? null : chapters.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.authorChapters, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _addChapter,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.authorNewChapter, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  // an icon: the header row has a phone's width to share
                  if (chapters.isNotEmpty)
                    DdxIconButton(
                      key: const ValueKey('au-part-add'),
                      icon: Icons.horizontal_rule,
                      tooltip: l10n.auPartAdd,
                      onPressed: () => _addPart(chapters, selected),
                    ),
                ],
              ),
            ),
            if (chapters.isEmpty && widget.module != null)
              KindEmptyState(module: widget.module!, note: l10n.authorNoChapters, startLabel: l10n.authorNewChapter, onStart: _addChapter)
            else if (chapters.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.authorNoChapters, style: theme.textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 40,
                child: Builder(builder: (_) {
                  // Procress 28 part 5: the Part dividers between the chapters
                  final rows = authorRows(chapters, parts);
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      if (r.part case final p?) {
                        return _PartMark(key: ValueKey('au-part-${p.id}'), part: p, onTap: () => _partMenu(p, chapters.length));
                      }
                      final c = r.chapter!;
                      return DdxChip.filter(
                        c.name,
                        selected: selected?.id == c.id,
                        onSelected: (_) => setState(() => _selectedId = c.id),
                      );
                    },
                  );
                }),
              ),
              if (selected != null)
                _ChapterEditor(
                  key: ValueKey(selected.id),
                  chapter: selected,
                  onDelete: () => _delete(selected),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// A Part divider among the chapter chips: a short rule with its name.
class _PartMark extends StatelessWidget {
  const _PartMark({super.key, required this.part, required this.onTap});
  final AuthorPart part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final rule = Container(width: 14, height: 1, color: muted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          rule,
          if (part.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(part.label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted, letterSpacing: .6)),
            )
          else
            const SizedBox(width: 6),
          rule,
        ]),
      ),
    );
  }
}

/// Procress 28 part 5: the chapter's name is typed where it is shown, and its
/// status and synopsis sit between the name and the text (as on the desktop).
class _ChapterEditor extends ConsumerStatefulWidget {
  final ChapterModel chapter;
  final VoidCallback onDelete;

  const _ChapterEditor({
    super.key,
    required this.chapter,
    required this.onDelete,
  });

  @override
  ConsumerState<_ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends ConsumerState<_ChapterEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TextEditingController _title = TextEditingController(text: widget.chapter.name);
  late final TextEditingController _synopsis = TextEditingController(text: widget.chapter.synopsis ?? '');
  final _titleFocus = FocusNode(), _synFocus = FocusNode();
  bool _dirty = false;
  // a save can run from dispose(), where context is off limits
  late final ProviderContainer _container = ProviderScope.containerOf(context, listen: false);

  @override
  void initState() {
    super.initState();
    _container; // resolved while the context is live
    _controller = TextEditingController(text: widget.chapter.content ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _save();
    });
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveTitle();
    });
    _synFocus.addListener(() {
      if (!_synFocus.hasFocus) _saveSynopsis();
    });
  }

  @override
  void dispose() {
    if (_dirty) _save();
    _saveTitle();
    _saveSynopsis();
    _controller.dispose();
    _focusNode.dispose();
    _title.dispose();
    _synopsis.dispose();
    _titleFocus.dispose();
    _synFocus.dispose();
    super.dispose();
  }

  // read before an await: the provider may be gone once the widget is
  Future<void> _saveTitle() async {
    final name = _title.text.trim();
    if (name.isEmpty || name == widget.chapter.name) return;
    final dao = _container.read(authorDaoProvider).valueOrNull;
    await dao?.renameChapter(widget.chapter.id, name, label: widget.chapter.label);
    _container.invalidate(chaptersProvider(widget.chapter.moduleRef));
  }

  Future<void> _saveSynopsis({String? status}) async {
    final syn = _synopsis.text;
    if (status == null && syn == (widget.chapter.synopsis ?? '')) return;
    final dao = _container.read(authorDaoProvider).valueOrNull;
    await dao?.setChapterMeta(widget.chapter.id, synopsis: syn, status: status);
    _container.invalidate(chaptersProvider(widget.chapter.moduleRef));
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    final dao = ref.read(authorDaoProvider).valueOrNull;
    await dao?.updateChapterContent(widget.chapter.id, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DdxField(
                  key: const ValueKey('au-title'),
                  controller: _title,
                  focusNode: _titleFocus,
                  size: DdxFieldSize.sm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _titleFocus.unfocus(),
                ),
              ),
              DdxIconButton(
                icon: Icons.delete_outline,
                tooltip: l10n.btnDelete,
                size: DdxIconSize.sm,
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButton<String>(
              key: const ValueKey('au-status'),
              value: authorStatuses.contains(widget.chapter.status) ? widget.chapter.status : '',
              isDense: true,
              items: [for (final s in ['', ...authorStatuses]) DropdownMenuItem(value: s, child: Text(authorStatusLabel(l10n, s)))],
              onChanged: (s) => _saveSynopsis(status: s ?? ''),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DdxField(
                key: const ValueKey('au-synopsis'),
                controller: _synopsis,
                focusNode: _synFocus,
                hint: l10n.auSynopsis,
                size: DdxFieldSize.sm,
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 8,
            maxLines: 24,
            decoration: InputDecoration(
              hintText: l10n.authorContentHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _dirty = true,
          ),
        ],
      ),
    );
  }
}

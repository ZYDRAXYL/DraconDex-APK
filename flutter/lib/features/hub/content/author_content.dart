import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/author_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Author kind: a book made of chapters. The chapter list picks one; the
/// editor below writes `book_chapter.chapter_content`.
///
/// Editing follows _DescriptionEditor's contract in module_explorer_screen —
/// save on blur and on dispose rather than on every keystroke, so a long
/// chapter is not one database write per character.
class AuthorContent extends ConsumerStatefulWidget {
  final int moduleId;
  const AuthorContent({super.key, required this.moduleId});

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

  Future<void> _rename(ChapterModel c) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.btnRename),
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
    if (name == null || name.isEmpty) return;
    final dao = ref.read(authorDaoProvider).valueOrNull;
    await dao?.renameChapter(c.id, name, label: c.label);
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
    await dao?.deleteChapter(c.id);
    if (!mounted) return;
    if (_selectedId == c.id) setState(() => _selectedId = null);
    ref.invalidate(chaptersProvider(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersProvider(widget.moduleId));

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
                  Text(l10n.authorChapters, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addChapter,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.authorNewChapter),
                  ),
                ],
              ),
            ),
            if (chapters.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.authorNoChapters, style: theme.textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final c = chapters[i];
                    return ChoiceChip(
                      label: Text(c.name, overflow: TextOverflow.ellipsis),
                      selected: selected?.id == c.id,
                      onSelected: (_) => setState(() => _selectedId = c.id),
                    );
                  },
                ),
              ),
              if (selected != null)
                _ChapterEditor(
                  key: ValueKey(selected.id),
                  chapter: selected,
                  onRename: () => _rename(selected),
                  onDelete: () => _delete(selected),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ChapterEditor extends ConsumerStatefulWidget {
  final ChapterModel chapter;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChapterEditor({
    super.key,
    required this.chapter,
    required this.onRename,
    required this.onDelete,
  });

  @override
  ConsumerState<_ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends ConsumerState<_ChapterEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chapter.content ?? '');
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
                child: Text(
                  widget.chapter.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l10n.btnRename,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: widget.onRename,
              ),
              IconButton(
                tooltip: l10n.btnDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 4),
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

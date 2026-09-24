import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/entity/entity_kinds.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/dao/author_dao.dart';
import '../../data/dao/classifier_dao.dart';
import '../../data/dao/hashtag_dao.dart';
import '../../data/dao/narrator_dao.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/hashtag_model.dart';
import '../../data/models/module_model.dart';
import '../../data/services/entity_location.dart';
import '../../data/services/wiki_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/row_menu.dart';
import '../../widgets/wiki_field.dart';
import 'component_registry.dart';
import 'page_providers.dart';
import 'views/classifier_views.dart';

/// Properties, Related, and an element page's body — the three components
/// every page can hold (EXE renderer/page/blocks.js, item-page.js).
final List<ComponentDef> coreComponents = [
  ComponentDef(
    id: 'core.properties',
    kind: null,
    once: true,
    label: (l) => l.pbProperties,
    build: (c, x) => PropertiesComponent(ctx: x),
  ),
  ComponentDef(
    id: 'core.related',
    kind: null,
    once: true,
    label: (l) => l.pbRelated,
    build: (c, x) => RelatedComponent(ctx: x),
  ),
  ComponentDef(
    id: 'item.body',
    kind: null,
    once: true,
    label: (l) => l.pbItemBody,
    build: (c, x) => x.itemKey == null || x.itemKey == '*'
        ? SharedLayoutNote(text: AppLocalizations.of(c)!.pbSharedLayout)
        : ItemBody(module: x.page.module, itemKey: x.itemKey!),
  ),
];

/// A markdown text that is read on the page and edited in a sheet: tap to
/// write. Every free-text field on a page goes through this, so every one of
/// them renders `[[links]]` and completes them while typing (V5.md §8.4).
class TextSourceEditor extends ConsumerWidget {
  final String text;
  final int nexusId;
  final String title;
  final String? emptyHint;
  final Future<void> Function(String value) onSave;
  final TextStyle? style;

  const TextSourceEditor({
    super.key,
    required this.text,
    required this.nexusId,
    required this.title,
    required this.onSave,
    this.emptyHint,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final next = await editTextSheet(context, title: title, initial: text, nexusId: nexusId);
        if (next != null && next != text) await onSave(next);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: text.trim().isEmpty
            ? Text(emptyHint ?? l10n.pbTextEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.45)))
            : MarkdownView(text: text, nexusId: nexusId, style: style),
      ),
    );
  }
}

/// Edits one text in a sheet with `[[` completion; null when cancelled.
Future<String?> editTextSheet(BuildContext context,
    {required String title, required String initial, required int nexusId, bool singleLine = false}) {
  final controller = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet)!;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(sheet).textTheme.titleMedium),
                const SizedBox(height: 8),
                WikiTextField(
                  controller: controller,
                  nexusId: nexusId,
                  autofocus: true,
                  minLines: singleLine ? 1 : 6,
                  maxLines: singleLine ? 1 : 16,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(sheet), child: Text(l10n.btnCancel)),
                    FilledButton(onPressed: () => Navigator.pop(sheet, controller.text), child: Text(l10n.btnSave)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

/// A module's description as a document — what the Drafter and Inspector
/// views are, and the top of Properties for every other kind.
class DescriptionDocument extends ConsumerWidget {
  final ModuleModel module;
  final bool tall;

  const DescriptionDocument({super.key, required this.module, this.tall = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tall ? 160 : 0),
      child: TextSourceEditor(
        text: module.description ?? '',
        nexusId: module.nexusRef,
        title: module.name,
        emptyHint: l10n.notesHint,
        onSave: (v) async {
          final dao = ref.read(moduleDaoProvider).valueOrNull;
          await dao?.updateModuleDescription(module.id, v);
          ref.invalidate(moduleProvider(module.id));
          ref.invalidate(nexusIndexProvider(module.nexusRef));
        },
      ),
    );
  }
}

class NotYetOnMobile extends StatelessWidget {
  final String label;
  const NotYetOnMobile({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text('$label · ${AppLocalizations.of(context)!.pbNotOnMobile}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
    );
  }
}

class SharedLayoutNote extends StatelessWidget {
  final String text;
  const SharedLayoutNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

// ── Properties ─────────────────────────────────────────────────────────────

/// The six property types (EXE blocks.js PROP_TYPES).
const propTypes = ['text', 'textarea', 'number', 'date', 'checkbox', 'url'];

String propTypeLabel(AppLocalizations l, String t) => switch (t) {
      'textarea' => l.propTypeTextarea,
      'number' => l.propTypeNumber,
      'date' => l.propTypeDate,
      'checkbox' => l.propTypeCheckbox,
      'url' => l.propTypeUrl,
      _ => l.propTypeText,
    };

/// core.properties: the description (except where the view IS the
/// description — Drafter, Inspector), the tags, and the page's property
/// blocks, each edited in place.
class PropertiesComponent extends ConsumerWidget {
  final ComponentCtx ctx;
  const PropertiesComponent({super.key, required this.ctx});

  static const _descInView = {ModuleKind.drafter, ModuleKind.inspector};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final m = ctx.page.module;
    final own = ctx.itemKey == null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (own && !_descInView.contains(m.kind)) DescriptionDocument(module: m),
        if (own) _TagRow(moduleId: m.id),
        for (final p in ctx.page.props) _PropRow(ctx: ctx, prop: p),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.pbAddProperty),
            onPressed: () => editPropSheet(context, ref, ctx, null),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}

class _PropRow extends ConsumerWidget {
  final ComponentCtx ctx;
  final PageBlock prop;
  const _PropRow({required this.ctx, required this.prop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final v = prop.content ?? '';
    Widget value;
    switch (prop.propType) {
      case 'checkbox':
        value = Align(
          alignment: AlignmentDirectional.centerStart,
          child: Checkbox(
            value: v == '1' || v == 'true',
            onChanged: (on) => _save(ref, on == true ? '1' : '0'),
          ),
        );
      case 'textarea':
        value = MarkdownView(text: v, nexusId: ctx.nexusId);
      default:
        value = Text(v, style: theme.textTheme.bodyMedium);
    }
    List<RowAction> actions() => [
          RowAction(label: l10n.btnEdit, icon: Icons.edit_outlined, onTap: () => editPropSheet(context, ref, ctx, prop)),
          RowAction(
            label: l10n.btnDelete,
            icon: Icons.delete_outline,
            danger: true,
            onTap: () => deleteBlockWithUndo(context, ref, ctx.key, prop.id),
          ),
        ];
    return InkWell(
      onTap: prop.propType == 'checkbox' ? null : () => editPropSheet(context, ref, ctx, prop),
      onLongPress: () => showRowMenu(context, actions(), title: prop.propName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(prop.propName ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
            ),
            Expanded(child: value),
            RowMenuButton(actions: actions, title: prop.propName, iconSize: 16, dense: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, String value) async {
    final dao = await ref.read(pageBlockDaoProvider.future);
    await dao.setProp(ctx.page.module.id, ctx.itemKey, prop.id, prop.propName ?? '', value, type: prop.propType ?? 'text');
    ref.invalidate(pageProvider(ctx.key));
  }
}

/// Add (prop null) or edit a property: name, type, value.
Future<void> editPropSheet(BuildContext context, WidgetRef ref, ComponentCtx ctx, PageBlock? prop) async {
  final l10n = AppLocalizations.of(context)!;
  final name = TextEditingController(text: prop?.propName ?? '');
  final value = TextEditingController(text: prop?.content ?? '');
  var type = prop?.propType ?? 'text';
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(prop == null ? l10n.pbAddProperty : (prop.propName ?? '')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: prop == null, decoration: InputDecoration(labelText: l10n.pbPropName)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(labelText: l10n.pbPropType),
                items: [for (final t in propTypes) DropdownMenuItem(value: t, child: Text(propTypeLabel(l10n, t)))],
                onChanged: (t) => setState(() => type = t ?? 'text'),
              ),
              const SizedBox(height: 8),
              if (type == 'textarea')
                WikiTextField(controller: value, nexusId: ctx.nexusId, minLines: 3, maxLines: 8)
              else if (type != 'checkbox')
                TextField(
                  controller: value,
                  keyboardType: type == 'number'
                      ? TextInputType.number
                      : type == 'url'
                          ? TextInputType.url
                          : TextInputType.text,
                  decoration: InputDecoration(hintText: type == 'date' ? 'YYYY-MM-DD' : null),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.btnSave)),
        ],
      ),
    ),
  );
  if (ok == true && name.text.trim().isNotEmpty) {
    final dao = await ref.read(pageBlockDaoProvider.future);
    final v = type == 'checkbox' ? (value.text == '1' ? '1' : '0') : value.text;
    await dao.setProp(ctx.page.module.id, ctx.itemKey, prop?.id, name.text.trim(), v, type: type);
    ref.invalidate(pageProvider(ctx.key));
  }
  name.dispose();
  value.dispose();
}

/// Deletes a block with an Undo in the snackbar rather than a confirm
/// (APK-V3.md §9.1 — the phone's way of the desktop's toast Undo).
Future<void> deleteBlockWithUndo(BuildContext context, WidgetRef ref, PageKey key, int id) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context)!;
  final dao = await ref.read(pageBlockDaoProvider.future);
  final rows = await dao.delete(id);
  ref.invalidate(pageProvider(key));
  messenger?.showSnackBar(SnackBar(
    content: Text(l10n.pbBlockDeleted),
    action: SnackBarAction(
      label: l10n.btnUndo,
      onPressed: () async {
        await dao.restore(rows);
        ref.invalidate(pageProvider(key));
      },
    ),
  ));
}

class _TagRow extends ConsumerWidget {
  final int moduleId;
  const _TagRow({required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(_moduleTagsProvider(moduleId)).valueOrNull ?? const <HashtagModel>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final t in tags)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: t.colorCode == null ? null : ColorDot(colorCode: t.colorCode, size: 10),
              label: Text('#${t.name}'),
            ),
          TextButton.icon(
            icon: const Icon(Icons.sell_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.pbTags),
            onPressed: () => _pickTags(context, ref, tags),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTags(BuildContext context, WidgetRef ref, List<HashtagModel> current) async {
    final db = await ref.read(databaseProvider.future);
    final all = await HashtagDao(db).getHashtags();
    final on = {for (final t in current) t.id};
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setState) => SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final t in all)
                CheckboxListTile(
                  value: on.contains(t.id),
                  title: Text('#${t.name}'),
                  secondary: t.colorCode == null ? null : ColorDot(colorCode: t.colorCode, size: 14),
                  onChanged: (v) async {
                    await HashtagDao(db).setModuleTag(moduleId, t.id, v == true);
                    setState(() => v == true ? on.add(t.id) : on.remove(t.id));
                    ref.invalidate(_moduleTagsProvider(moduleId));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final _moduleTagsProvider = FutureProvider.autoDispose.family<List<HashtagModel>, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  return HashtagDao(db).getModuleTags(moduleId);
});

// ── Related ────────────────────────────────────────────────────────────────

class RelatedEntry {
  final String key;
  final String name;
  final String? label;
  const RelatedEntry(this.key, this.name, this.label);
}

class RelatedData {
  final List<RelatedEntry> relations;
  final List<RelatedEntry> backlinks;
  final List<RelatedEntry> outgoing;
  const RelatedData(this.relations, this.backlinks, this.outgoing);
  bool get isEmpty => relations.isEmpty && backlinks.isEmpty && outgoing.isEmpty;
}

/// Relations both ways, what links here, and what this page links to.
final relatedProvider = FutureProvider.autoDispose.family<RelatedData, String>((ref, key) async {
  final db = await ref.watch(databaseProvider.future);
  Future<List<RelatedEntry>> named(Iterable<(String, String?)> keys) async => [
        for (final (k, label) in keys)
          if (await EntityKinds.nameOf(db, k) case final String n) RelatedEntry(k, n, label),
      ];
  final rels = await db.rawQuery('SELECT from_key, to_key, label FROM entity_relation WHERE from_key=? OR to_key=?', [key, key]);
  final relKeys = [
    for (final r in rels) (r['from_key'] == key ? r['to_key'] as String : r['from_key'] as String, r['label'] as String?),
  ];
  final back = await WikiService.backlinks(db, key);
  final out = await db.rawQuery('SELECT DISTINCT target_key FROM wiki_link WHERE src_key=? AND target_key IS NOT NULL', [key]);
  return RelatedData(
    await named(relKeys),
    await named([for (final k in back) (k, null)]),
    await named([for (final r in out) (r['target_key'] as String, null)]),
  );
});

class RelatedComponent extends ConsumerWidget {
  final ComponentCtx ctx;
  const RelatedComponent({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final key = ctx.itemKey == null || ctx.itemKey == '*' ? 'module_${ctx.page.module.id}' : ctx.itemKey!;
    final data = ref.watch(relatedProvider(key)).valueOrNull;
    if (data == null) return const SizedBox(height: 24);
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(l10n.pbNoRelated,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      );
    }
    Widget group(String title, List<RelatedEntry> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in rows)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(r.label == null || r.label!.isEmpty ? r.name : '${r.name} · ${r.label}'),
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        final db = await ref.read(databaseProvider.future);
                        final loc = await EntityLocation.of(db, r.key);
                        if (loc != null) router.push(loc);
                      },
                    ),
                ],
              ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group(l10n.pbRelations, data.relations),
        group(l10n.pbBacklinks, data.backlinks),
        group(l10n.pbOutgoing, data.outgoing),
      ],
    );
  }
}

// ── an element page's body ─────────────────────────────────────────────────

/// What the element IS, on its own page: an object's note and field values,
/// a chapter's text, an event's story, a dialogue's description, a chat's
/// messages. Editable where the desktop's element page is.
class ItemBody extends ConsumerWidget {
  final ModuleModel module;
  final String itemKey;
  const ItemBody({super.key, required this.module, required this.itemKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_itemBodyProvider(itemKey)).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (data == null) return const SizedBox(height: 40);
    Future<void> saved() async {
      ref.invalidate(_itemBodyProvider(itemKey));
      ref.invalidate(nexusIndexProvider(module.nexusRef));
      ref.invalidate(relatedProvider(itemKey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.text != null)
          TextSourceEditor(
            text: data.text!,
            nexusId: module.nexusRef,
            title: data.name,
            onSave: (v) async {
              final db = await ref.read(databaseProvider.future);
              await data.saveText!(db, v);
              await saved();
            },
          ),
        if (data.classifierModule != null) ClsItemFields(moduleId: data.classifierModule!, itemId: data.id),
        for (final f in data.fields)
          InkWell(
            onTap: f.editable
                ? () async {
                    final next = await editTextSheet(context,
                        title: f.name, initial: f.value, nexusId: module.nexusRef, singleLine: f.singleLine);
                    if (next == null) return;
                    final db = await ref.read(databaseProvider.future);
                    await ClassifierDao(db).setValue(objectRef: data.id, templateRef: f.templateId, value: next);
                    await saved();
                    if (data.classifierModule != null) ref.invalidate(clsDataProvider(data.classifierModule!));
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(f.name,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
                  ),
                  Expanded(
                    child: f.value.isEmpty
                        ? Text('—', style: theme.textTheme.bodyMedium)
                        : MarkdownView(text: f.value, nexusId: module.nexusRef),
                  ),
                ],
              ),
            ),
          ),
        if (data.lines.isNotEmpty)
          for (final line in data.lines)
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: MarkdownView(text: line, nexusId: module.nexusRef)),
        if (data.text == null && data.fields.isEmpty && data.lines.isEmpty && data.classifierModule == null)
          Text(l10n.pbItemEmpty, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Field {
  final int templateId;
  final String name;
  final String value;
  final bool editable;
  final bool singleLine;
  const _Field(this.templateId, this.name, this.value, {required this.editable, required this.singleLine});
}

class _ItemBodyData {
  final int id;
  final String name;
  final String? text;
  final Future<void> Function(Database db, String v)? saveText;
  final List<_Field> fields;
  final List<String> lines;
  final int? classifierModule;
  const _ItemBodyData(this.id, this.name,
      {this.text, this.saveText, this.fields = const [], this.lines = const [], this.classifierModule});
}

final _itemBodyProvider = FutureProvider.autoDispose.family<_ItemBodyData?, String>((ref, key) async {
  final db = await ref.watch(databaseProvider.future);
  final k = EntityKinds.parse(key);
  if (k == null) return null;
  final (prefix, id) = k;
  final name = await EntityKinds.nameOf(db, key) ?? key;
  switch (prefix) {
    case 'cobj':
      final o = await db.rawQuery('SELECT name, note, module_ref FROM classifier_object WHERE id=?', [id]);
      if (o.isEmpty) return null;
      final fields = await db.rawQuery('''
        SELECT t.id, t.description, t.attribute_type, a.attribute_value FROM classifier_template t
        JOIN classifier_object o ON o.module_ref = t.module_ref
        LEFT JOIN classifier_attribute a ON a.template_ref = t.id AND a.object_ref = o.id
        WHERE o.id=? AND t.object_ref = o.id
        ORDER BY t.display_order, t.id''', [id]);
      return _ItemBodyData(id, name,
          text: o.first['note'] as String? ?? '',
          saveText: (d, v) => ClassifierDao(d).updateItem(id, name: o.first['name'] as String, note: v),
          // The module's shared fields draw through ClsItemFields, typed;
          // only the element's private ones (desktop-made) are listed here.
          classifierModule: o.first['module_ref'] as int,
          fields: [
            for (final f in fields)
              if (f['attribute_type'] != 'relation' && f['attribute_type'] != 'formula')
                _Field(f['id'] as int, f['description'] as String? ?? '', f['attribute_value'] as String? ?? '',
                    editable: const {'text', 'textarea', 'number', 'date', 'url', null}.contains(f['attribute_type']),
                    singleLine: f['attribute_type'] != 'textarea'),
          ]);
    case 'bchp':
      final c = await db.rawQuery('SELECT chapter_content FROM book_chapter WHERE id=?', [id]);
      if (c.isEmpty) return null;
      return _ItemBodyData(id, name,
          text: c.first['chapter_content'] as String? ?? '',
          saveText: (d, v) => AuthorDao(d).updateChapterContent(id, v));
    case 'sdlg':
      final s = await db.rawQuery('SELECT name, description FROM story_dialogue WHERE id=?', [id]);
      if (s.isEmpty) return null;
      return _ItemBodyData(id, name,
          text: s.first['description'] as String? ?? '',
          saveText: (d, v) => NarratorDao(d).updateDialogue(id, name: s.first['name'] as String, description: v));
    case 'chss':
      final msgs = await db.rawQuery('SELECT message FROM chat_message WHERE session_ref=? ORDER BY id', [id]);
      return _ItemBodyData(id, name, lines: [for (final m in msgs) m['message'] as String? ?? '']);
    default:
      return _ItemBodyData(id, name);
  }
});

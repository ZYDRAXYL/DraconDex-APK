import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/classifier_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Classifier kind: define fields once for the module, then fill them in per
/// item. Mirrors the desktop mod/classifier.js split — the field definitions
/// (`classifier_template`) are module-level, the items are
/// `classifier_object`, and a value is one `classifier_attribute` row keyed
/// by the pair.
class ClassifierContent extends ConsumerWidget {
  final int moduleId;
  const ClassifierContent({super.key, required this.moduleId});

  Future<String?> _askName(BuildContext context, String title, {String initial = ''}) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fieldsAsync = ref.watch(classifierFieldsProvider(moduleId));
    final itemsAsync = ref.watch(classifierItemsProvider(moduleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- fields -------------------------------------------------
          Row(
            children: [
              Text(l10n.classifierFields, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final name = await _askName(context, l10n.classifierNewField);
                  if (name == null || name.isEmpty) return;
                  final dao = ref.read(classifierDaoProvider).valueOrNull;
                  await dao?.createField(moduleRef: moduleId, description: name);
                  ref.invalidate(classifierFieldsProvider(moduleId));
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.classifierNewField),
              ),
            ],
          ),
          fieldsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (fields) => fields.isEmpty
                ? Text(l10n.classifierNoFields, style: theme.textTheme.bodySmall)
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in fields)
                        InputChip(
                          label: Text(f.description),
                          onPressed: () async {
                            final name = await _askName(
                              context, l10n.btnRename, initial: f.description);
                            if (name == null || name.isEmpty) return;
                            final dao = ref.read(classifierDaoProvider).valueOrNull;
                            await dao?.renameField(f.id, name);
                            ref.invalidate(classifierFieldsProvider(moduleId));
                          },
                          onDeleted: () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: l10n.confirmDeleteTitle,
                              // Deleting a field drops its value on every item.
                              message: l10n.classifierDeleteFieldWarning,
                            );
                            if (!ok) return;
                            final dao = ref.read(classifierDaoProvider).valueOrNull;
                            await dao?.deleteField(f.id);
                            ref.invalidate(classifierFieldsProvider(moduleId));
                          },
                        ),
                    ],
                  ),
          ),
          const Divider(height: 24),
          // ---- items --------------------------------------------------
          Row(
            children: [
              Text(l10n.classifierItems, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final name = await _askName(context, l10n.classifierNewItem);
                  if (name == null || name.isEmpty) return;
                  final dao = ref.read(classifierDaoProvider).valueOrNull;
                  await dao?.createItem(moduleRef: moduleId, name: name);
                  ref.invalidate(classifierItemsProvider(moduleId));
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.classifierNewItem),
              ),
            ],
          ),
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (items) => items.isEmpty
                ? Text(l10n.classifierNoItems, style: theme.textTheme.bodySmall)
                : Column(
                    children: [
                      for (final item in items)
                        _ItemTile(
                          key: ValueKey(item.id),
                          moduleId: moduleId,
                          item: item,
                          fields: fieldsAsync.valueOrNull ?? const [],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One item, expanding to its per-field values. Values load only when the
/// tile is opened, so a module with many items does not run a query each.
class _ItemTile extends ConsumerWidget {
  final int moduleId;
  final ClassifierItemModel item;
  final List<ClassifierFieldModel> fields;

  const _ItemTile({
    super.key,
    required this.moduleId,
    required this.item,
    required this.fields,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(item.name, overflow: TextOverflow.ellipsis),
      subtitle: item.note == null || item.note!.isEmpty
          ? null
          : Text(item.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
      children: [
        if (fields.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.classifierNoFields,
                style: Theme.of(context).textTheme.bodySmall),
          )
        else
          Consumer(
            builder: (ctx, r, _) {
              final valuesAsync = r.watch(classifierValuesProvider(item.id));
              return valuesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Text('$e',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                data: (values) => Column(
                  children: [
                    for (final f in fields)
                      _ValueField(
                        key: ValueKey('${item.id}:${f.id}'),
                        objectId: item.id,
                        field: f,
                        initial: values[f.id] ?? '',
                      ),
                  ],
                ),
              );
            },
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: l10n.confirmDeleteTitle,
                message: l10n.confirmDeleteMessage,
              );
              if (!ok) return;
              final dao = ref.read(classifierDaoProvider).valueOrNull;
              await dao?.deleteItem(item.id);
              ref.invalidate(classifierItemsProvider(moduleId));
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l10n.btnDelete),
          ),
        ),
      ],
    );
  }
}

class _ValueField extends ConsumerStatefulWidget {
  final int objectId;
  final ClassifierFieldModel field;
  final String initial;

  const _ValueField({
    super.key,
    required this.objectId,
    required this.field,
    required this.initial,
  });

  @override
  ConsumerState<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends ConsumerState<_ValueField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
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
    final dao = ref.read(classifierDaoProvider).valueOrNull;
    await dao?.setValue(
      objectRef: widget.objectId,
      templateRef: widget.field.id,
      value: _controller.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.field.description,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _dirty = true,
      ),
    );
  }
}

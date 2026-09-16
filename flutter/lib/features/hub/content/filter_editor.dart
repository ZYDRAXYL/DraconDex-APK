import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/viewer_model.dart';

/// The saved-filter editor, shared by Viewer and Connector exactly as the
/// desktop shares openSavedFilterPopup between mod/viewer.js and
/// mod/connector.js — one definition, one editor, two lenses over it.
///
/// Returns the edited definition, or null if dismissed. Nothing is written
/// here; the caller persists it.
Future<FilterDef?> showFilterEditor(
  BuildContext context, {
  required FilterDef initial,
  required List<IndexedItem> modules,
}) {
  return showDialog<FilterDef>(
    context: context,
    builder: (ctx) => _FilterEditorDialog(initial: initial, modules: modules),
  );
}

class _FilterEditorDialog extends StatefulWidget {
  final FilterDef initial;

  /// The Nexus's modules, taken straight from the index rows whose itemKind
  /// is 'module' — the childOf picker needs nothing the index does not
  /// already carry, so this avoids a second query.
  final List<IndexedItem> modules;
  const _FilterEditorDialog({required this.initial, required this.modules});

  @override
  State<_FilterEditorDialog> createState() => _FilterEditorDialogState();
}

class _FilterEditorDialogState extends State<_FilterEditorDialog> {
  late List<List<FilterRule>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = widget.initial.groups.map((g) => g.rules.toList()).toList();
    if (_groups.isEmpty) _groups = [<FilterRule>[]];
  }

  FilterDef get _def =>
      FilterDef(groups: _groups.map((r) => FilterGroup(rules: r)).toList());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.filterTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.filterExplain, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (var gi = 0; gi < _groups.length; gi++) ...[
                if (gi > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(l10n.filterOr,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var ri = 0; ri < _groups[gi].length; ri++)
                          _RuleRow(
                            rule: _groups[gi][ri],
                            modules: widget.modules,
                            showAnd: ri > 0,
                            onChanged: (r) => setState(() => _groups[gi][ri] = r),
                            onRemove: () => setState(() => _groups[gi].removeAt(ri)),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _groups[gi].add(
                                const FilterRule(field: 'name', op: 'contains'))),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l10n.filterAddRule),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () => setState(() => _groups.add(<FilterRule>[])),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.filterAddGroup),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.btnCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_def),
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final FilterRule rule;
  final List<IndexedItem> modules;
  final bool showAnd;
  final ValueChanged<FilterRule> onChanged;
  final VoidCallback onRemove;

  const _RuleRow({
    required this.rule,
    required this.modules,
    required this.showAnd,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String fieldLabel(String f) => switch (f) {
          'kind' => l10n.filterFieldKind,
          'childOf' => l10n.filterFieldChildOf,
          'hashtag' => l10n.filterFieldHashtag,
          _ => l10n.filterFieldName,
        };
    String opLabel(String o) => switch (o) {
          'is' => l10n.filterOpIs,
          'isNot' => l10n.filterOpIsNot,
          'startsWith' => l10n.filterOpStartsWith,
          'endsWith' => l10n.filterOpEndsWith,
          _ => l10n.filterOpContains,
        };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAnd)
            Text(l10n.filterAnd,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          Row(
            children: [
              DropdownButton<String>(
                value: rule.field,
                isDense: true,
                items: [
                  for (final f in const ['name', 'hashtag', 'kind', 'childOf'])
                    DropdownMenuItem(value: f, child: Text(fieldLabel(f))),
                ],
                onChanged: (f) {
                  if (f == null) return;
                  onChanged(FilterRule(field: f, op: 'contains'));
                },
              ),
              const SizedBox(width: 6),
              if (rule.field == 'name' || rule.field == 'hashtag')
                DropdownButton<String>(
                  value: rule.op,
                  isDense: true,
                  items: [
                    for (final o in const ['is', 'isNot', 'startsWith', 'endsWith', 'contains'])
                      DropdownMenuItem(value: o, child: Text(opLabel(o))),
                  ],
                  onChanged: (o) => o == null
                      ? null
                      : onChanged(FilterRule(
                          field: rule.field, op: o, value: rule.value)),
                ),
              const Spacer(),
              IconButton(
                tooltip: l10n.btnDelete,
                icon: const Icon(Icons.close, size: 16),
                onPressed: onRemove,
              ),
            ],
          ),
          if (rule.field == 'name' || rule.field == 'hashtag')
            TextFormField(
              initialValue: rule.value,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) =>
                  onChanged(FilterRule(field: rule.field, op: rule.op, value: v)),
            ),
          if (rule.field == 'kind')
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final k in ModuleKind.values)
                  FilterChip(
                    label: Text(moduleKindInfo[k]!.label,
                        style: theme.textTheme.labelSmall),
                    selected: rule.values.contains(k.id),
                    onSelected: (on) {
                      final next = rule.values.toList();
                      if (on) {
                        next.add(k.id);
                      } else {
                        next.remove(k.id);
                      }
                      onChanged(FilterRule(field: 'kind', values: next));
                    },
                  ),
              ],
            ),
          if (rule.field == 'childOf')
            DropdownButton<int>(
              value: modules.any((m) => m.id == rule.moduleId) ? rule.moduleId : null,
              isDense: true,
              isExpanded: true,
              hint: Text(l10n.filterPickModule),
              items: [
                for (final m in modules)
                  DropdownMenuItem(value: m.moduleId, child: Text(m.moduleName)),
              ],
              onChanged: (id) =>
                  onChanged(FilterRule(field: 'childOf', moduleId: id)),
            ),
        ],
      ),
    );
  }
}

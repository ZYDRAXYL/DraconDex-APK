import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/entity/entity_kinds.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/diviner_dao.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/markdown_view.dart';
import '../../../widgets/row_menu.dart';
import '../component_registry.dart';
import 'view_common.dart';

/// The Diviner's page (EXE mod/diviner.js): its tables, the open one's roll
/// button and last result, its entries, and its roll history.

class DivinerData {
  final List<Map<String, Object?>> tables;
  final int? selected;
  final List<Map<String, Object?>> entries;
  final List<Map<String, Object?>> rolls;
  final Map<String, String> linkNames;
  const DivinerData(this.tables, this.selected, this.entries, this.rolls, this.linkNames);

  Map<String, Object?>? get table => tables.where((t) => t['id'] == selected).firstOrNull;
}

final divinerProvider = FutureProvider.autoDispose.family<DivinerData, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final dao = DivinerDao(db);
  final tables = await dao.tables(moduleId);
  final ui = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='activeTable'", [moduleId]);
  var sel = ui.isEmpty ? null : int.tryParse(ui.first['ui_value'] as String? ?? '');
  if (!tables.any((t) => t['id'] == sel)) sel = tables.isEmpty ? null : tables.first['id'] as int;
  final entries = sel == null ? const <Map<String, Object?>>[] : await dao.entries(sel);
  final rolls = sel == null ? const <Map<String, Object?>>[] : await dao.rolls(sel);
  final names = <String, String>{};
  for (final e in entries) {
    final k = e['linker_key'] as String?;
    if (k != null) names[k] = await EntityKinds.nameOf(db, k) ?? k;
  }
  return DivinerData(tables, sel, entries, rolls, names);
});

class DivinerView extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const DivinerView({super.key, required this.ctx});

  @override
  ConsumerState<DivinerView> createState() => _DivinerViewState();
}

class _DivinerViewState extends ConsumerState<DivinerView> {
  DivinerResult? _last;
  String? _quick;

  int get _id => widget.ctx.source.id;
  Future<DivinerDao> _dao() async => DivinerDao(await ref.read(databaseProvider.future));
  void _refresh() => ref.invalidate(divinerProvider(_id));

  Future<void> _select(int id) async {
    final db = await ref.read(databaseProvider.future);
    await db.insert('module_ui', {'module_ref': _id, 'ui_key': 'activeTable', 'ui_value': '$id'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    setState(() => _last = null);
    _refresh();
  }

  /// New table ([t] null) or its settings: name, dice (empty = weighted), mode.
  Future<void> _tableDialog([Map<String, Object?>? t]) async {
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController(text: t?['name'] as String? ?? '');
    final dice = TextEditingController(text: t?['dice'] as String? ?? '');
    var mode = t?['mode'] as String? ?? 'pick';
    String? error;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(t == null ? l.divNewTable : l.btnEdit),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: t == null, decoration: InputDecoration(labelText: l.labelName)),
              TextField(
                controller: dice,
                decoration: InputDecoration(labelText: l.divDice, hintText: '1d20 · 2d6+1 · d%', helperText: l.divDiceHelp, errorText: error),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pick', label: Text(l.divModePick)),
                  ButtonSegment(value: 'join', label: Text(l.divModeJoin)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setLocal(() => mode = s.first),
              ),
            ]),
          ),
          actions: [
            if (t != null)
              TextButton(
                onPressed: () => Navigator.pop(d, 'delete'),
                child: Text(l.btnDelete, style: TextStyle(color: Theme.of(d).colorScheme.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
            FilledButton(
              onPressed: () {
                if (dice.text.trim().isNotEmpty && Dice.parse(dice.text) == null) {
                  setLocal(() => error = l.divBadDice);
                  return;
                }
                Navigator.pop(d, 'save');
              },
              child: Text(l.btnSave),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim(), dc = dice.text.trim();
    name.dispose();
    dice.dispose();
    if (ok == null) return;
    final dao = await _dao();
    if (ok == 'delete') {
      if (!mounted || !await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
      await dao.deleteTable(t!['id'] as int);
    } else if (n.isNotEmpty) {
      if (t == null) {
        await _select(await dao.createTable(_id, n, dice: dc, mode: mode));
      } else {
        await dao.updateTable(t['id'] as int, n, dc, mode);
      }
    }
    _refresh();
    ref.invalidate(nexusIndexProvider(widget.ctx.nexusId));
  }

  Future<void> _entryDialog(DivinerData d, Map<String, Object?> e) async {
    final l = AppLocalizations.of(context)!;
    final dice = d.table?['dice'] != null;
    final text = TextEditingController(text: e['entry_text'] as String? ?? '');
    final lo = TextEditingController(text: '${e['range_lo'] ?? ''}');
    final hi = TextEditingController(text: '${e['range_hi'] ?? ''}');
    final weight = TextEditingController(text: '${e['weight'] ?? 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(l.btnEdit),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, autofocus: true, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: l.divEntryText)),
            if (dice)
              Row(children: [
                Expanded(child: TextField(controller: lo, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.divFrom))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: hi, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.divTo))),
              ])
            else
              TextField(controller: weight, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.divWeight)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: Text(l.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(l.btnSave)),
        ],
      ),
    );
    if (ok == true) {
      await (await _dao()).updateEntry(e['id'] as int,
          text: text.text, lo: int.tryParse(lo.text.trim()), hi: int.tryParse(hi.text.trim()), weight: int.tryParse(weight.text.trim()));
      _refresh();
    }
    for (final c in [text, lo, hi, weight]) {
      c.dispose();
    }
  }

  void _entryMenu(DivinerData d, Map<String, Object?> e) {
    final l = AppLocalizations.of(context)!;
    final tableId = d.selected!;
    showRowMenu(context, [
      RowAction(label: l.btnEdit, icon: Icons.edit_outlined, onTap: () => _entryDialog(d, e)),
      RowAction(
        label: l.divRollsTable,
        icon: Icons.casino_outlined,
        onTap: () async {
          final dao = await _dao();
          final tables = await dao.tablesInNexus(widget.ctx.nexusId);
          final blocked = <int>{for (final t in tables) if (await dao.wouldCycle(tableId, t['id'] as int)) t['id'] as int};
          if (!mounted) return;
          final pick = await showDialog<int>(
            context: context,
            builder: (dc) => SimpleDialog(title: Text(l.divRollsTable), children: [
              for (final t in tables)
                SimpleDialogOption(
                  // A table that would loop back here is shown, not offered.
                  onPressed: blocked.contains(t['id']) ? null : () => Navigator.pop(dc, t['id'] as int),
                  child: Text('${t['name']} · ${t['module_name']}',
                      style: blocked.contains(t['id']) ? TextStyle(color: Theme.of(dc).disabledColor) : null),
                ),
            ]),
          );
          if (pick == null) return;
          await dao.updateEntry(e['id'] as int, linkerKey: 'divt_$pick');
          _refresh();
        },
      ),
      RowAction(
        label: l.divLinkEntity,
        icon: Icons.link,
        onTap: () async {
          final it = await pickEntity(context, ref, widget.ctx.nexusId);
          if (it == null) return;
          await (await _dao()).updateEntry(e['id'] as int, linkerKey: it.key);
          _refresh();
        },
      ),
      if (e['linker_key'] != null)
        RowAction(
          label: l.divUnlink,
          icon: Icons.link_off,
          onTap: () async {
            await (await _dao()).updateEntry(e['id'] as int, clearLink: true);
            _refresh();
          },
        ),
      RowAction(
        label: l.btnDelete,
        icon: Icons.delete_outline,
        danger: true,
        onTap: () async {
          await (await _dao()).deleteEntry(e['id'] as int);
          _refresh();
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final d = ref.watch(divinerProvider(_id)).valueOrNull;
    if (d == null) return const SizedBox(height: 48);
    final t = d.table;
    final quick = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(isDense: true, hintText: l.divQuickRoll, prefixIcon: const Icon(Icons.casino_outlined, size: 18)),
            onSubmitted: (v) => setState(() => _quick = rollDice(v)?.text ?? l.divBadDice),
          ),
        ),
        if (_quick != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(_quick!, style: theme.textTheme.titleSmall)),
      ]),
    );
    final tables = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        for (final tb in d.tables)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onLongPress: () => _tableDialog(tb),
              child: ChoiceChip(
                label: Text('${tb['name']}${tb['dice'] != null ? ' · ${tb['dice']}' : ''}'),
                selected: tb['id'] == d.selected,
                onSelected: (_) => _select(tb['id'] as int),
              ),
            ),
          ),
        ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(l.divNewTable), onPressed: () => _tableDialog()),
      ]),
    );
    if (t == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tables, EmptyHint(l.divNoTables), quick]);
    }
    final dice = t['dice'] != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tables,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          FilledButton.icon(
            onPressed: d.entries.isEmpty
                ? null
                : () async {
                    final r = await (await _dao()).roll(t['id'] as int);
                    setState(() => _last = r);
                    _refresh();
                  },
            icon: const Icon(Icons.casino),
            label: Text(l.divRoll),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: l.btnEdit, icon: const Icon(Icons.tune), onPressed: () => _tableDialog(t)),
          // The table's own page (V5.md §12.4): its notes, properties and links.
          IconButton(
            tooltip: l.rowOpen,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openElement(context, widget.ctx.nexusId, _id, 'divt_${t['id']}'),
          ),
          const Spacer(),
          Text(t['mode'] == 'join' ? l.divModeJoin : (dice ? '${t['dice']}' : l.divWeighted), style: theme.textTheme.labelMedium),
        ]),
      ),
      if (_last != null)
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_last!.dice != null) Text(_last!.dice!, style: theme.textTheme.labelMedium),
              MarkdownView(text: _last!.text.isEmpty ? '—' : _last!.text, nexusId: widget.ctx.nexusId, style: theme.textTheme.titleMedium),
            ]),
          ),
        ),
      ViewBar(title: l.divEntries, actions: [
        IconButton(
          tooltip: l.btnAdd,
          icon: const Icon(Icons.add),
          onPressed: () async {
            await (await _dao()).createEntry(t['id'] as int);
            _refresh();
          },
        ),
      ]),
      if (d.entries.isEmpty) EmptyHint(l.divNoEntries),
      for (final e in d.entries)
        ListTile(
          dense: true,
          leading: SizedBox(
            width: 48,
            child: Text(
              dice
                  ? (e['range_lo'] == null
                      ? '—'
                      : e['range_lo'] == e['range_hi']
                          ? '${e['range_lo']}'
                          : '${e['range_lo']}–${e['range_hi']}')
                  : '×${e['weight'] ?? 1}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          title: Text((e['entry_text'] as String?)?.isNotEmpty == true ? e['entry_text'] as String : '…'),
          subtitle: e['linker_key'] == null
              ? null
              : Text((e['linker_key'] as String).startsWith('divt_')
                  ? '🎲 ${d.linkNames[e['linker_key']] ?? ''}'
                  : '[[${d.linkNames[e['linker_key']] ?? ''}]]'),
          selected: _last?.entryId == e['id'],
          onTap: () => _entryDialog(d, e),
          onLongPress: () => _entryMenu(d, e),
        ),
      ViewBar(title: l.divHistory, actions: [
        if (d.rolls.isNotEmpty)
          IconButton(
            tooltip: l.btnClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              await (await _dao()).clearRolls(t['id'] as int);
              _refresh();
            },
          ),
      ]),
      for (final r in d.rolls.take(10))
        ListTile(
          dense: true,
          title: Text((r['result_text'] as String?)?.isNotEmpty == true ? r['result_text'] as String : '—'),
          subtitle: r['dice_result'] == null ? null : Text(r['dice_result'] as String),
          trailing: Text((r['create_at'] as String? ?? '').replaceFirst(RegExp(r'^\d{4}-'), ''), style: theme.textTheme.labelSmall),
        ),
      quick,
      const SizedBox(height: 8),
    ]);
  }
}

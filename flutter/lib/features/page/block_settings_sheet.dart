import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/dao/page_block_dao.dart';
import '../../providers/navigation_providers.dart';
import '../tools/assets_screen.dart';
import 'block_options.dart';
import 'block_style.dart';
import 'links.dart';
import 'module_page.dart';
import 'page_providers.dart';
import 'page_strings.dart';

/// The ⚙ on a block while arranging — the phone's sheet for the desktop's
/// popover (EXE renderer/page/style-pop.js, APP docs/TEMPLATES.md §6):
/// Style (variant, accent, width, align, density, header, fold, anchor,
/// hideOn) and Options (what the component declares). Every change is
/// saved as it is made; Reset clears the open tab, and "Use on every block
/// of this kind" copies the style to the page's other blocks of the kind
/// (anchor and header title stay per block).
Future<void> showBlockSettings(BuildContext context, WidgetRef ref, PageKey pageKey, int blockId) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlockSettingsSheet(pageKey: pageKey, blockId: blockId),
    );

class BlockSettingsSheet extends ConsumerStatefulWidget {
  final PageKey pageKey;
  final int blockId;
  const BlockSettingsSheet({super.key, required this.pageKey, required this.blockId});

  @override
  ConsumerState<BlockSettingsSheet> createState() => _BlockSettingsSheetState();
}

class _BlockSettingsSheetState extends ConsumerState<BlockSettingsSheet> {
  int _tab = 0;

  Future<void> _save(PageBlock b, Map<String, Object?> config) async {
    final dao = await ref.read(pageBlockDaoProvider.future);
    await dao.update(b.id, config: config, clear: {if (config.isEmpty) 'config'});
    ref.invalidate(pageProvider(widget.pageKey));
  }

  /// The anchor, made unique on the page (b12-2 …), as the desktop does.
  Future<void> _setAnchor(PageData page, PageBlock b, String raw) async {
    var a = BlockStyle.cleanAnchor(raw);
    final taken = {
      for (final o in page.blocks)
        if (o.id != b.id) BlockStyle.of(o.config).anchor.isNotEmpty ? BlockStyle.of(o.config).anchor : 'b${o.id}',
    };
    for (var n = 2; a.isNotEmpty && taken.contains(a); n++) {
      a = '${BlockStyle.cleanAnchor(raw)}-$n';
    }
    await _save(b, styleWith(b.config, 'anchor', a));
  }

  Future<void> _applyToKind(PageData page, PageBlock b) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final style = {...?(b.config['style'] as Map?)?.cast<String, Object?>()}..remove('anchor');
    final mine = (style['header'] as Map?)?.cast<String, Object?>();
    final dao = await ref.read(pageBlockDaoProvider.future);
    var n = 0;
    for (final o in page.blocks) {
      if (o.id == b.id || o.type != b.type || o.component != b.component) continue;
      final theirs = (o.config['style'] as Map?)?.cast<String, Object?>() ?? const {};
      final next = {...style};
      // each block keeps its own anchor and header title
      if (theirs['anchor'] != null) next['anchor'] = theirs['anchor'];
      final th = (theirs['header'] as Map?)?.cast<String, Object?>();
      if (mine != null || th != null) next['header'] = {...?mine, 'title': th?['title'] ?? ''};
      await dao.update(o.id, config: {...o.config, 'style': next});
      n++;
    }
    ref.invalidate(pageProvider(widget.pageKey));
    messenger.showSnackBar(SnackBar(content: Text(l10n.pbStyleApplied.replaceAll('{n}', '$n'))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final page = ref.watch(pageProvider(widget.pageKey)).valueOrNull;
    final b = page?.blocks.where((x) => x.id == widget.blockId).firstOrNull;
    if (page == null || b == null) return const SizedBox(height: 120);
    final opts = optionsOf(b);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${l10n.pbBlockSettings} — ${BlockView.nameOf(l10n, b)}', style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: [ButtonSegment(value: 0, label: Text(l10n.pbStyle)), ButtonSegment(value: 1, label: Text(l10n.pbOptions))],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.viewInsetsOf(context).bottom),
              child: _tab == 0 ? _style(context, page, b) : _options(context, page, b, opts),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, overflowSpacing: 4, children: [
              TextButton(
                onPressed: () => _save(b, {...b.config}..remove(_tab == 0 ? 'style' : 'opts')),
                child: Text(l10n.pbStyleReset),
              ),
              if (_tab == 0) OutlinedButton(onPressed: () => _applyToKind(page, b), child: Text(l10n.pbStyleApplyAll)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Style ─────────────────────────────────────────────────────────────
  Widget _style(BuildContext context, PageData page, PageBlock b) {
    final l10n = AppLocalizations.of(context)!;
    final st = BlockStyle.of(b.config);
    Widget h(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(t, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
        );
    Widget seg(String key, String prefix) {
      final vals = key == 'hideOn' && b.component == 'item.body' ? const ['none'] : BlockStyle.values[key]!;
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final v in vals)
          ChoiceChip(
            label: Text(choiceText(l10n, prefix, v)),
            selected: st[key] == v,
            onSelected: (_) => _save(b, styleWith(b.config, key, v)),
          ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      h(l10n.pbStyleVariant),
      seg('variant', 'pbVariant'),
      h(l10n.pbStyleAccent),
      Wrap(spacing: 10, runSpacing: 8, children: [
        for (final a in BlockStyle.values['accent']!)
          Tooltip(
            message: choiceText(l10n, 'pbAcc', a),
            child: Semantics(
              selected: st.accent == a,
              button: true,
              label: choiceText(l10n, 'pbAcc', a),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _save(b, styleWith(b.config, 'accent', a)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor(context, a),
                    shape: BoxShape.circle,
                    border: Border.all(color: st.accent == a ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                  ),
                  child: st.accent == a ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              ),
            ),
          ),
      ]),
      h(l10n.pbStyleWidth),
      seg('width', 'pbWidth'),
      h(l10n.pbStyleAlign),
      seg('align', 'align'),
      h(l10n.pbStyleDensity),
      seg('density', 'pbDensity'),
      h(l10n.pbStyleHeader),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.pbHeaderShow),
        value: st.headerShow,
        onChanged: (v) => _save(b, styleHeaderWith(b.config, show: v)),
      ),
      _Field(
        initial: st.headerTitle,
        label: l10n.pbHeaderTitle,
        hint: BlockView.nameOf(l10n, b),
        maxLength: 80,
        onDone: (v) => _save(b, styleHeaderWith(b.config, title: v)),
      ),
      h(l10n.pbStyleCollapsible),
      seg('collapsible', 'pbColl'),
      h(l10n.pbStyleAnchor),
      _Field(initial: st.anchor, label: l10n.pbStyleAnchor, hint: 'b${b.id}', maxLength: 40, onDone: (v) => _setAnchor(page, b, v)),
      h(l10n.pbStyleHideOn),
      seg('hideOn', 'pbHide'),
    ]);
  }

  // ── Options ───────────────────────────────────────────────────────────
  Widget _options(BuildContext context, PageData page, PageBlock b, List<OptDef> opts) {
    final l10n = AppLocalizations.of(context)!;
    if (opts.isEmpty) return Padding(padding: const EdgeInsets.all(12), child: Text(l10n.pbNoOptions));
    final nexusId = page.module.nexusRef;
    Future<void> set(String key, Object? v) => _save(b, configWithOpt(b.config, key, v));
    Widget h(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(t, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
        );
    final out = <Widget>[];
    for (final d in opts) {
      final v = optValue(b, d.key);
      final label = pageText(l10n, d.label);
      switch (d.type) {
        case OptType.select:
          out.addAll([
            h(label),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in d.choices)
                ChoiceChip(
                  label: Text(d.choicePrefix.isEmpty ? c : choiceText(l10n, d.choicePrefix, c)),
                  selected: '$v' == c,
                  onSelected: (_) => set(d.key, c == d.defaultValue ? null : c),
                ),
            ]),
          ]);
        case OptType.toggle:
          out.add(SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: v == true, onChanged: (x) => set(d.key, x)));
        case OptType.number:
          out.addAll([
            h(label),
            _Field(
              initial: v == null ? '' : '$v',
              label: label,
              number: true,
              onDone: (x) {
                final n = num.tryParse(x.trim());
                return set(d.key, n == null ? null : optValid(d, n));
              },
            ),
          ]);
        case OptType.text:
          out.addAll([h(label), _Field(initial: '${v ?? ''}', label: label, maxLength: (d.max ?? 200).toInt(), onDone: (x) => set(d.key, x.trim()))]);
        case OptType.list:
          out.addAll([h(label), _ListEditor(values: [for (final s in (v as List?) ?? const []) '$s'], max: (d.max ?? 12).toInt(), onChanged: (x) => set(d.key, x.isEmpty ? null : x))]);
        case OptType.links:
          out.addAll([h(label), _LinksEditor(links: linksFrom(v), grouped: d.grouped, nexusId: nexusId, onChanged: (x) => set(d.key, x.isEmpty ? null : [for (final l in x) l.toJson()]))]);
        case OptType.image:
          out.addAll([
            h(label),
            Row(children: [
              Expanded(child: Text(v == null ? '—' : '$v', style: TextStyle(color: context.ddx.textMuted))),
              TextButton(
                onPressed: () async {
                  final id = await pickAsset(context, ref, nexusId, classes: d.classes);
                  if (id != null) await set(d.key, 'file_$id');
                },
                child: Text(l10n.pbChooseFile),
              ),
              if (v != null) IconButton(tooltip: l10n.btnDelete, icon: const Icon(Icons.close), onPressed: () => set(d.key, null)),
            ]),
          ]);
        case OptType.images:
          final list = [for (final r in (v as List?) ?? const []) '$r'];
          out.addAll([
            h('$label · ${list.length}'),
            Wrap(spacing: 6, children: [
              for (final r in list) InputChip(label: Text(r), onDeleted: () => set(d.key, [...list]..remove(r))),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.pcAddFile),
                onPressed: () async {
                  final id = await pickAsset(context, ref, nexusId, classes: d.classes);
                  if (id != null && !list.contains('file_$id')) await set(d.key, [...list, 'file_$id']);
                },
              ),
            ]),
          ]);
        case OptType.module:
          final index = ref.watch(nexusIndexProvider(nexusId)).valueOrNull ?? const [];
          final mods = index.where((e) => e.itemKind == 'module').toList()..sort((a, b) => a.name.compareTo(b.name));
          out.addAll([
            h(label),
            DropdownButtonFormField<int?>(
              initialValue: mods.any((m) => m.moduleId == v) ? v as int? : null,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (final m in mods) DropdownMenuItem<int?>(value: m.moduleId, child: Text(m.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (x) => set(d.key, x),
            ),
          ]);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

/// A text field that saves when the user is done with it (submit, or
/// leaving it) — not on every keystroke.
class _Field extends StatefulWidget {
  final String initial, label;
  final String? hint;
  final int? maxLength;
  final bool number;
  final Future<void> Function(String) onDone;
  const _Field({super.key, required this.initial, required this.label, required this.onDone, this.hint, this.maxLength, this.number = false});

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _c = TextEditingController(text: widget.initial);
  late String _saved = widget.initial;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    if (_c.text == _saved) return;
    _saved = _c.text;
    widget.onDone(_c.text);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        maxLength: widget.maxLength,
        keyboardType: widget.number ? TextInputType.number : null,
        decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), hintText: widget.hint, counterText: '', labelText: widget.label),
        onSubmitted: (_) => _done(),
        onTapOutside: (_) => _done(),
      );
}

/// A short list of names (a tabs block's tabs): edit, remove, add.
class _ListEditor extends StatelessWidget {
  final List<String> values;
  final int max;
  final ValueChanged<List<String>> onChanged;
  const _ListEditor({required this.values, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < values.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              child: _Field(
                key: ValueKey('li$i${values[i]}'),
                initial: values[i],
                label: '${l10n.pcTab} ${i + 1}',
                maxLength: 40,
                onDone: (v) async => onChanged([...values]..[i] = v.trim()),
              ),
            ),
            IconButton(tooltip: l10n.btnDelete, icon: const Icon(Icons.close), onPressed: () => onChanged([...values]..removeAt(i))),
          ]),
        ),
      if (values.length < max)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.pbListAdd),
            onPressed: () => onChanged([...values, '${l10n.pcTab} ${values.length + 1}']),
          ),
        ),
    ]);
  }
}

/// The `links` option's editor (EXE pbLinksEditorHtml): one row per link —
/// its label and where it goes, typed the way it reads ([[Name]], #anchor,
/// https://…) and parsed when it is saved; a web address that is not
/// http(s) is refused there.
class _LinksEditor extends ConsumerWidget {
  final List<PageLink> links;
  final bool grouped;
  final int nexusId;
  final ValueChanged<List<PageLink>> onChanged;
  const _LinksEditor({required this.links, required this.grouped, required this.nexusId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final index = ref.watch(nexusIndexProvider(nexusId)).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    void bad() => messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkBadUrl)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < links.length; i++)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Field(
                key: ValueKey('ll$i${links[i].label}'),
                initial: links[i].label,
                label: l10n.pbLinkLabel,
                maxLength: 80,
                onDone: (v) async => onChanged([...links]..[i] = links[i].copyWith(label: v.trim())),
              ),
              const SizedBox(height: 6),
              _Field(
                key: ValueKey('lt$i${links[i].to}'),
                initial: linkInputOf(links[i], resolveLink(links[i], index)),
                label: l10n.pbLinkTo,
                hint: '[[…]] · #… · https://',
                maxLength: 400,
                onDone: (v) async {
                  final to = parseLinkInput(v, index);
                  if (to == null) return bad();
                  onChanged([...links]..[i] = links[i].copyWith(to: to));
                },
              ),
              if (grouped) ...[
                const SizedBox(height: 6),
                _Field(
                  key: ValueKey('lg$i${links[i].group}'),
                  initial: links[i].group,
                  label: l10n.pbLinkGroup,
                  maxLength: 40,
                  onDone: (v) async => onChanged([...links]..[i] = links[i].copyWith(group: v.trim())),
                ),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  tooltip: l10n.pbLinkUp,
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0 ? null : () => onChanged([...links]..insert(i - 1, links[i])..removeAt(i + 1)),
                ),
                IconButton(
                  tooltip: l10n.pbLinkDown,
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == links.length - 1 ? null : () => onChanged([...links]..insert(i + 2, links[i])..removeAt(i)),
                ),
                IconButton(tooltip: l10n.btnDelete, icon: const Icon(Icons.close), onPressed: () => onChanged([...links]..removeAt(i))),
              ]),
            ]),
          ),
        ),
      if (links.length < 60)
        _Field(
          key: ValueKey('new${links.length}'),
          initial: '',
          label: l10n.pbLinkAdd,
          hint: l10n.pbLinkAddPh,
          maxLength: 400,
          onDone: (raw) async {
            if (raw.trim().isEmpty) return;
            final to = parseLinkInput(raw, index);
            if (to == null) return bad();
            final label = RegExp(r'^\[\[|^#|^https?:', caseSensitive: false).hasMatch(raw.trim()) ? '' : raw.trim();
            onChanged([...links, PageLink(to, label: to.startsWith('wiki:') ? '' : label)]);
          },
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(l10n.pbLinkHint, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
      ),
    ]);
  }
}

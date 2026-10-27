import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/icon_refs.dart';
import '../../core/icon_sets.dart';
import '../../data/dao/color_dao.dart';
import '../../data/dao/module_dao.dart';
import '../../data/models/color_model.dart';
import '../../providers/db_providers.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/color_picker_widget.dart';
import '../../widgets/ddx_field.dart';
import '../../widgets/ddx_popover.dart';
import '../../widgets/ddx_ref_icon.dart';
import '../../widgets/ddx_segmented.dart';

/// The icon & colour chooser (Procress 29 part 7) — the desktop's icon popup
/// (EXE iconpicker.js) on the phone: the app's own icons and the three open
/// sets (one at a time, searchable across all), a letter or emoji of your own,
/// the pictures already uploaded in this Nexus, and the palette with a colour
/// of your own. Each pick saves at once through [onIcon] / [onColor], and only
/// that half — a colour never rewrites the icon, nor the reverse.
Future<void> showIconPicker(
  BuildContext context, {
  required int nexusId,
  String? icon,
  String? colorCode,
  required Future<void> Function(String? icon) onIcon,
  required Future<void> Function(ColorModel color) onColor,
}) {
  return showDdxPopover<void>(
    context: context,
    width: 340,
    maxHeight: 520,
    semanticLabel: AppLocalizations.of(context)!.clsColorIcon,
    builder: (_) => _IconPicker(nexusId: nexusId, icon: icon, colorCode: colorCode, onIcon: onIcon, onColor: onColor),
  );
}

const _app = 'app';
const _custom = 'custom';

class _IconPicker extends ConsumerStatefulWidget {
  final int nexusId;
  final String? icon;
  final String? colorCode;
  final Future<void> Function(String? icon) onIcon;
  final Future<void> Function(ColorModel color) onColor;
  const _IconPicker({required this.nexusId, this.icon, this.colorCode, required this.onIcon, required this.onColor});

  @override
  ConsumerState<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends ConsumerState<_IconPicker> {
  late String? _icon = widget.icon;
  late String? _color = widget.colorCode;
  late String _tab = () {
    final key = (_icon ?? '').replaceFirst('svg:', '');
    return IconSets.isSetRef(key) ? key.split('/').first : _app;
  }();
  String _query = '';
  List<String> _uploads = const [];
  List<ColorModel> _colors = const [];
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = glyphForRef(_icon);
    if (g != null) _text.text = g;
    () async {
      final db = await ref.read(databaseProvider.future);
      final up = await ModuleDao(db).uploadedIcons(widget.nexusId);
      final cs = await ColorDao(db).getColors();
      if (mounted) setState(() { _uploads = up; _colors = cs; });
    }();
    if (_tab != _app) IconSets.load(_tab).then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickIcon(String? ref) async {
    setState(() => _icon = ref);
    await widget.onIcon(ref);
  }

  Future<void> _pickColor(ColorModel c) async {
    setState(() => _color = c.colorCode);
    await widget.onColor(c);
  }

  // A search runs through every set, so the first letter typed loads them all.
  Future<void> _search(String q) async {
    setState(() => _query = q.trim().toLowerCase());
    if (_query.isNotEmpty) {
      await Future.wait(IconSets.ids.map(IconSets.load));
      if (mounted) setState(() {});
    }
  }

  List<String> _refs() {
    if (_query.isNotEmpty) {
      final words = _query.split(RegExp(r'\s+'));
      bool hit(String name, String extra) => words.every((w) => name.contains(w) || extra.contains(w));
      return [
        for (final k in appIconKeys) if (hit(k.toLowerCase(), '')) 'svg:$k',
        for (final id in IconSets.ids)
          if (IconSets.loaded(id) case final IconSet set)
            for (final n in set.icons.keys) if (hit(n, set.words(n))) 'svg:$id/$n',
      ];
    }
    if (_tab == _app) return [for (final k in appIconKeys) 'svg:$k'];
    final set = IconSets.loaded(_tab);
    return set == null ? const [] : [for (final n in set.icons.keys) 'svg:$_tab/$n'];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = _color != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(_color!)
        ? Color(int.parse('ff${_color!.substring(1)}', radix: 16))
        : theme.colorScheme.primary;
    Widget cell(String ref, Widget child) => InkWell(
          key: ValueKey('ipk-$ref'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickIcon(ref),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ref == _icon ? theme.colorScheme.primary : theme.dividerColor),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        );
    final grid = _tab == _custom && _query.isEmpty
        ? ListView(padding: const EdgeInsets.only(top: 8), children: [
            Row(children: [
              Expanded(child: DdxField(
                key: const ValueKey('ipk-text'),
                controller: _text,
                size: DdxFieldSize.sm,
                label: l.iconCustomText,
                maxLength: 16,
                onSubmitted: (_) => _useText(),
              )),
              const SizedBox(width: 8),
              TextButton(key: const ValueKey('ipk-text-use'), onPressed: _useText, child: Text(l.iconUse)),
            ]),
            if (_uploads.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.iconUploadedHere, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final u in _uploads) SizedBox.square(dimension: 40, child: cell(u, DdxRefIcon(u, size: 32))),
              ]),
            ],
            const SizedBox(height: 12),
            TextButton.icon(onPressed: () => _pickIcon(null), icon: const Icon(Icons.block, size: 18), label: Text(l.iconNone)),
          ])
        : Builder(builder: (_) {
            final refs = _refs();
            return GridView.builder(
              padding: const EdgeInsets.only(top: 8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 44, mainAxisSpacing: 6, crossAxisSpacing: 6),
              itemCount: refs.length,
              itemBuilder: (_, i) => cell(refs[i], DdxRefIcon(refs[i], size: 22, color: color)),
            );
          });
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SizedBox(
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DdxSegmented<String>(
              segments: [
                const DdxSegment(value: _app, label: 'DraconDex'),
                for (final id in IconSets.ids) DdxSegment(value: id, label: IconSets.labels[id]!),
                DdxSegment(value: _custom, label: l.iconCustom),
              ],
              selected: _tab,
              onChanged: (v) async {
                setState(() => _tab = v);
                if (v != _app && v != _custom) {
                  await IconSets.load(v);
                  if (mounted) setState(() {});
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          DdxField(key: const ValueKey('ipk-search'), size: DdxFieldSize.sm, hint: l.searchHint, prefixIcon: const Icon(Icons.search, size: 18), onChanged: _search),
          Expanded(child: grid),
          const Divider(height: 16),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              InkWell(
                key: const ValueKey('ipk-color-custom'),
                customBorder: const CircleBorder(),
                onTap: () => showColorPicker(context, ref, currentColorCode: _color, onColorSelected: _pickColor),
                child: Tooltip(message: l.colorCustom, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.palette_outlined, size: 22))),
              ),
              for (final c in _colors)
                InkWell(
                  key: ValueKey('ipk-color-${c.id}'),
                  customBorder: const CircleBorder(),
                  onTap: () => _pickColor(c),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: c.colorCode == _color ? theme.colorScheme.onSurface : Colors.transparent, width: 2)),
                      child: ColorDot(colorCode: c.colorCode, size: 20),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  // one or two characters as the eye sees them — stored like a symbol (sym:)
  void _useText() {
    final g = _text.text.trim().characters.take(2).toString();
    if (g.isNotEmpty) _pickIcon('sym:$g');
  }
}

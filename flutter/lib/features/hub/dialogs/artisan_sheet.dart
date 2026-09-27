import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/ddx_theme.dart';
import '../../../data/models/module_model.dart';
import '../../../data/services/bundle_service.dart';
import '../../../providers/db_providers.dart';
import '../../../widgets/confirm_dialog.dart';

/// The Artisan sheet (APP docs/TEMPLATES.md §4; EXE hub/bundles.js): the
/// bundles in three tabs — Classic, Genre (with the guide) and Mine, the
/// user's own from "Save as Artisan bundle…". A card makes its project at
/// once, or "Adjust first" opens the name, the sample data and the modules
/// to keep. Resolves to the spec [BundleService.create] builds, or null.
Future<Map<String, dynamic>?> pickArtisanBundle(BuildContext context, WidgetRef ref, int nexusId) async {
  final locale = Localizations.localeOf(context).languageCode;
  final db = await ref.read(databaseProvider.future);
  final catalog = await BundleService.loadBundles(locale);
  final mine = await BundleService.listMine(db, nexusId);
  var tab = 1;
  try {
    tab = (await SharedPreferences.getInstance()).getInt(_tabKey)?.clamp(0, 2) ?? 1;
  } catch (_) {}
  if (!context.mounted) return null;
  final picked = await showModalBottomSheet<(Map<String, dynamic>, bool)>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    // M3 caps a sheet at 640 wide, which would keep a tablet in the one-pane
    // layout; the gallery + detail pair wants the room (mockup 08-artisan)
    constraints: const BoxConstraints(maxWidth: 1100),
    builder: (s) => _ArtisanSheet(catalog: catalog, mine: mine, initialTab: tab, locale: locale),
  );
  if (picked == null || !context.mounted) return null;
  final (spec, adjustFirst) = picked;
  if (!adjustFirst) return spec;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => _AdjustSheet(spec: spec),
  );
}

const _tabKey = 'bundleTab';
const _groups = ['classic', 'genre', 'mine'];

/// A catalog entry, or one of Mine, as the spec [BundleService.create] takes.
Map<String, dynamic> _specOf(Map<String, dynamic> b) =>
    {...((b['spec'] as Map?) ?? const {}).cast<String, dynamic>(), 'name': b['name'], if (b['icon'] != null) 'icon': b['icon']};

class _ArtisanSheet extends StatefulWidget {
  final List<Map<String, dynamic>> catalog, mine;
  final int initialTab;
  final String locale;
  const _ArtisanSheet({required this.catalog, required this.mine, required this.initialTab, required this.locale});

  @override
  State<_ArtisanSheet> createState() => _ArtisanSheetState();
}

/// Mockup 08-artisan.html: the shelves as cards, and beside them (a tablet)
/// or in place of them (a phone, with a way back) what the selected bundle
/// will build.
class _ArtisanSheetState extends State<_ArtisanSheet> with SingleTickerProviderStateMixin {
  late final List<Map<String, dynamic>> _mine = [...widget.mine];
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab)..addListener(_onTab);
  Map<String, dynamic>? _sel;

  // a narrow sheet shows the detail only once a card was tapped
  bool _opened = false;

  List<Map<String, dynamic>> _shelf(int i) => _groups[i] == 'mine' ? _mine : [for (final b in widget.catalog) if ((b['group'] ?? 'genre') == _groups[i]) b];

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    setState(() => _sel = null);
    SharedPreferences.getInstance().then((p) => p.setInt(_tabKey, _tabs.index)).catchError((_) => false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _create(Map<String, dynamic> b, {required bool adjust, required bool samples}) =>
      Navigator.pop(context, ({..._specOf(b), if (!samples) 'includeSamples': false}, adjust));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final h = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: h * .86,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final shelf = _shelf(_tabs.index);
          final sel = _sel ?? (wide && shelf.isNotEmpty ? shelf.first : null);
          final detail = sel == null
              ? null
              : _BundleDetail(
                  key: ValueKey(sel['id']),
                  bundle: sel,
                  onBack: wide ? null : () => setState(() => _opened = false),
                  onCreate: (adjust, samples) => _create(sel, adjust: adjust, samples: samples),
                );
          if (!wide && _opened && detail != null) return detail;
          final gallery = Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text(l.fromTemplate, style: Theme.of(context).textTheme.titleMedium)),
            ),
            TabBar(controller: _tabs, tabs: [Tab(text: l.bundleTabClassic), Tab(text: l.bundleTabGenre), Tab(text: l.bundleTabMine)]),
            Expanded(
              child: TabBarView(controller: _tabs, children: [
                for (var i = 0; i < 3; i++) _grid(l, i, wide ? sel : null),
              ]),
            ),
          ]);
          if (!wide) return gallery;
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: gallery),
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 12, 12),
                child: detail ?? _mineHint(l),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _mineHint(AppLocalizations l) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.bundleMineEmpty, textAlign: TextAlign.center, style: TextStyle(color: context.ddx.textMuted)),
      );

  Widget _grid(AppLocalizations l, int i, Map<String, dynamic>? sel) {
    final bundles = _shelf(i);
    final mine = _groups[i] == 'mine';
    if (mine && bundles.isEmpty) return _mineHint(l);
    return GridView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 150, mainAxisSpacing: 10, crossAxisSpacing: 10),
      children: [
        for (final b in bundles)
          _BundleCard(
            bundle: b,
            selected: identical(b, sel),
            onTap: () => setState(() {
              _sel = b;
              _opened = true;
            }),
            onDelete: !mine
                ? null
                : () async {
                    final container = ProviderScope.containerOf(context);
                    if (!await showConfirmDialog(context, message: l.presetDeleteConfirm)) return;
                    final db = await container.read(databaseProvider.future);
                    await db.rawDelete('DELETE FROM module_preset WHERE id=?', [int.parse('${b['id']}'.substring(2))]);
                    setState(() {
                      _mine.remove(b);
                      if (identical(_sel, b)) _sel = null;
                    });
                  },
          ),
        if (_groups[i] == 'genre')
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final spec = await BundleService.loadGuide(widget.locale);
                if (mounted) Navigator.pop(context, (spec, false));
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.school_outlined),
                  const SizedBox(height: 8),
                  Text(l.guideTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Expanded(child: Text(l.guideDesc, overflow: TextOverflow.fade, style: TextStyle(fontSize: 12, color: context.ddx.textMuted))),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

List<ModuleKind> _kindsOf(Map spec) => {
      for (final m in (spec['modules'] as List?) ?? const [])
        if (m is Map && m['kind'] is String) ModuleKind.fromId(m['kind'] as String),
    }.toList();

/// The bundle's colours: its first two kinds, under a scrim so white text
/// holds 4.5:1 over the lightest kind colour (lime, yellow) — as on EXE.
Decoration _cover(Map spec) {
  final kinds = _kindsOf(spec);
  final a = kindColor[kinds.firstOrNull] ?? kindColor[ModuleKind.collector]!;
  final b = kinds.length > 1 ? kindColor[kinds[1]]! : a;
  Color dim(Color c) => Color.alphaBlend(Colors.black.withValues(alpha: .5), c);
  return BoxDecoration(gradient: LinearGradient(colors: [dim(a), dim(b)], begin: Alignment.topLeft, end: Alignment.bottomRight));
}

IconData _iconOf(Map spec) => moduleKindInfo[_kindsOf(spec).firstOrNull]?.icon ?? Icons.folder_outlined;

class _BundleCard extends StatelessWidget {
  final Map<String, dynamic> bundle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _BundleCard({required this.bundle, required this.selected, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final spec = (bundle['spec'] as Map?) ?? const {};
    final desc = '${bundle['description'] ?? ''}';
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? theme.colorScheme.primary : theme.dividerColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 48,
            decoration: _cover(spec),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Icon(_iconOf(spec), color: Colors.white, size: 22),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${bundle['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(desc, overflow: TextOverflow.fade, style: TextStyle(fontSize: 11.5, color: context.ddx.textMuted)),
                    ),
                  )
                else
                  const Spacer(),
                Wrap(spacing: 4, children: [
                  for (final k in _kindsOf(spec))
                    Tooltip(
                      message: kindName(AppLocalizations.of(context)!, k),
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: kindColor[k], borderRadius: BorderRadius.circular(3))),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// What a bundle will build (EXE bundleDetailHtml): the tree, the links,
/// and the one choice that is not "Adjust first" — its examples.
class _BundleDetail extends StatefulWidget {
  final Map<String, dynamic> bundle;
  final VoidCallback? onBack;
  final void Function(bool adjust, bool samples) onCreate;
  const _BundleDetail({super.key, required this.bundle, required this.onCreate, this.onBack});

  @override
  State<_BundleDetail> createState() => _BundleDetailState();
}

class _BundleDetailState extends State<_BundleDetail> {
  bool _samples = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final spec = (widget.bundle['spec'] as Map?) ?? const {};
    final sh = BundleService.shape({...spec, 'name': widget.bundle['name']});
    final desc = '${widget.bundle['description'] ?? ''}';
    final counts = l.artCounts
        .replaceAll('{f}', '${sh.folders}')
        .replaceAll('{m}', '${sh.mods.length}')
        .replaceAll('{l}', '${sh.links.length}')
        .replaceAll('{s}', '${sh.samples}');
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: .5, color: context.ddx.textMuted, fontWeight: FontWeight.w600)),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: _cover(spec),
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (widget.onBack != null)
                  IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white), tooltip: MaterialLocalizations.of(context).backButtonTooltip)
                else
                  const SizedBox(width: 8),
                Icon(_iconOf(spec), color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.bundle['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(desc, style: const TextStyle(fontSize: 12.5))),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(counts, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
            head(l.artStructure),
            for (final r in sh.rows)
              Padding(
                padding: EdgeInsets.only(left: r.depth * 16.0, top: 3, bottom: 3),
                child: Row(children: [
                  if (r.kind == null)
                    Icon(Icons.folder_outlined, size: 16, color: context.ddx.textMuted)
                  else
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: kindColor[ModuleKind.fromId(r.kind!)], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  if (r.kind != null) Text(kindName(l, ModuleKind.fromId(r.kind!)), style: TextStyle(fontSize: 11, color: context.ddx.textMuted)),
                  if (r.samples > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                      child: Text('+${r.samples}', style: const TextStyle(fontSize: 11)),
                    ),
                ]),
              ),
            if (sh.mods.length > 1) ...[
              head(l.artLinks),
              Container(
                decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)),
                child: AspectRatio(
                  aspectRatio: 400 / 190,
                  child: CustomPaint(painter: _LinksPainter(sh, theme.textTheme.bodySmall ?? const TextStyle(), theme.colorScheme.onSurface, theme.colorScheme.primary, theme.colorScheme.surfaceContainerHighest, theme.dividerColor)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 14, runSpacing: 4, children: [
                  _legend(context, l.artLinkRel, dashed: false),
                  _legend(context, l.artLinkBorrow, dashed: true),
                ]),
              ),
            ],
            if (sh.samples > 0) ...[
              head(l.artBefore),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${l.bundleIncludeSamples} · ${sh.samples}'),
                value: _samples,
                onChanged: (v) => setState(() => _samples = v),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => widget.onCreate(true, _samples), child: Text(l.bundleAdjust)),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => widget.onCreate(false, _samples), child: Text(l.bundleCreate)),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(BuildContext context, String text, {required bool dashed}) => Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(size: const Size(18, 2), painter: _LinePainter(dashed ? Theme.of(context).colorScheme.primary : context.ddx.textMuted, dashed)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 11, color: context.ddx.textMuted)),
      ]);
}

class _LinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LinePainter(this.color, this.dashed);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
      return;
    }
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(min(x + 4, size.width), size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.color != color;
}

/// Modules on an ellipse joined by their links (EXE bundleLinksSvg): nodes
/// in the theme's own colours with the kind as a stripe, so a light kind
/// colour never carries text.
class _LinksPainter extends CustomPainter {
  final BundleShape shape;
  final TextStyle style; // the theme's, so the label keeps the app font on web
  final Color text, accent, node, line;
  _LinksPainter(this.shape, this.style, this.text, this.accent, this.node, this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 400;
    canvas.scale(k);
    const cx = 200.0, cy = 95.0, rx = 150.0, ry = 70.0;
    final pos = <String, Offset>{};
    final n = shape.mods.length;
    for (final (i, m) in shape.mods.indexed) {
      final a = -pi / 2 + i * 2 * pi / n;
      pos[m.ref] = Offset(cx + rx * cos(a), cy + ry * sin(a));
    }
    for (final l in shape.links) {
      final a = pos[l.from], b = pos[l.to];
      if (a == null || b == null) continue;
      final p = Paint()
        ..color = l.borrow ? accent : line
        ..strokeWidth = 1.5;
      if (!l.borrow) {
        canvas.drawLine(a, b, p);
        continue;
      }
      final d = b - a, len = d.distance;
      for (double t = 0; t < len; t += 7) {
        canvas.drawLine(a + d * (t / len), a + d * (min(t + 4, len) / len), p);
      }
    }
    for (final m in shape.mods) {
      final c = pos[m.ref]!;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 80, height: 22), const Radius.circular(6));
      canvas.drawRRect(r, Paint()..color = node);
      canvas.drawRRect(r, Paint()
        ..color = line
        ..style = PaintingStyle.stroke);
      canvas.drawRect(Rect.fromLTWH(c.dx - 40, c.dy - 11, 4, 22), Paint()..color = kindColor[ModuleKind.fromId(m.kind)] ?? line);
      final tp = TextPainter(
        text: TextSpan(text: m.name, style: style.copyWith(color: text, fontSize: 10.5, height: 1.2)),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      tp.paint(canvas, Offset(c.dx + 2 - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LinksPainter o) => !identical(o.shape, shape) || o.text != text;
}

/// "Adjust first": the project's name, the sample data, and which modules
/// to keep — each renamed, its fields renamed or (blank) left out.
class _AdjustSheet extends StatefulWidget {
  final Map<String, dynamic> spec;
  const _AdjustSheet({required this.spec});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late final List<Map> _mods = [for (final m in (widget.spec['modules'] as List?) ?? const []) if (m is Map) m];
  late final _name = TextEditingController(text: '${widget.spec['name'] ?? ''}');
  late final Set<int> _keep = {for (var i = 0; i < _mods.length; i++) i};
  late final Map<int, TextEditingController> _names = {for (final (i, m) in _mods.indexed) i: TextEditingController(text: '${m['name'] ?? ''}')};
  final Map<String, TextEditingController> _fields = {};
  late final bool _hasSamples = BundleService.hasSamples(widget.spec);
  bool _samples = true;

  TextEditingController _field(int i, int k, String name) => _fields.putIfAbsent('$i:$k', () => TextEditingController(text: name));

  @override
  void dispose() {
    _name.dispose();
    for (final c in [..._names.values, ..._fields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _create() {
    final l = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.nameRequired)));
      return;
    }
    Navigator.pop(
      context,
      BundleService.adjust(
        widget.spec,
        name: name,
        keep: _keep,
        names: {for (final e in _names.entries) e.key: e.value.text},
        fieldNames: {for (final e in _fields.entries) e.key: e.value.text},
        includeSamples: !_hasSamples || _samples,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), children: [
                Text('${widget.spec['name'] ?? ''} · ${l.bundleAdjust}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(controller: _name, decoration: InputDecoration(labelText: l.bundleProjectName)),
                if (_hasSamples)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.bundleIncludeSamples),
                    value: _samples,
                    onChanged: (v) => setState(() => _samples = v),
                  ),
                const SizedBox(height: 8),
                Text(l.bundleIncludes, style: Theme.of(context).textTheme.labelLarge),
                for (final (i, m) in _mods.indexed) _module(l, i, m),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l.btnCancel)),
                const SizedBox(width: 8),
                FilledButton(onPressed: _keep.isEmpty ? null : _create, child: Text(l.bundleCreate)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _module(AppLocalizations l, int i, Map m) {
    final on = _keep.contains(i);
    final fields = [for (final f in (m['fields'] as List?) ?? const []) if (f is Map) f];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Checkbox(value: on, onChanged: (v) => setState(() => v == true ? _keep.add(i) : _keep.remove(i))),
        Icon(moduleKindInfo[ModuleKind.fromId('${m['kind']}')]!.icon, size: 18, color: context.ddx.textMuted),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _names[i], enabled: on, decoration: const InputDecoration(isDense: true))),
      ]),
      if (on && fields.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            title: Text('${l.bundleFields} (${fields.length})', style: const TextStyle(fontSize: 13)),
            children: [
              for (final (k, f) in fields.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(controller: _field(i, k, '${f['name'] ?? ''}'), decoration: const InputDecoration(isDense: true)),
                ),
            ],
          ),
        ),
    ]);
  }
}

/// "Save as Artisan bundle…" on a folder: its subtree, structure only or
/// with up to three examples per module, kept in this vault as one of Mine.
Future<void> showSaveBundleDialog(BuildContext context, WidgetRef ref, ModuleModel folder) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final c = TextEditingController(text: folder.name);
  var samples = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(l.bundleSaveMine.replaceAll('…', '')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: l.nameField)),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            initialValue: samples,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.bundleSaveData),
            items: [
              DropdownMenuItem(value: false, child: Text(l.bundleDataNone)),
              DropdownMenuItem(value: true, child: Text(l.bundleDataSamples)),
            ],
            onChanged: (v) => set(() => samples = v ?? false),
          ),
          const SizedBox(height: 10),
          Text(l.bundleSaveHint, style: TextStyle(fontSize: 12, color: d.ddx.textMuted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
        ],
      ),
    ),
  );
  final name = c.text.trim();
  c.dispose();
  if (ok != true) return;
  if (name.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l.nameRequired)));
    return;
  }
  final db = await ref.read(databaseProvider.future);
  final n = await BundleService.saveMine(db, folder.nexusRef, folder.id, name, samples: samples);
  messenger.showSnackBar(SnackBar(content: Text('${l.bundleSaved} · $n')));
}

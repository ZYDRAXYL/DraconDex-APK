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

class _ArtisanSheetState extends State<_ArtisanSheet> {
  late final List<Map<String, dynamic>> _mine = [...widget.mine];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final h = MediaQuery.sizeOf(context).height;
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: h * .82,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text(l.fromTemplate, style: Theme.of(context).textTheme.titleMedium)),
            ),
            TabBar(
              onTap: (i) async {
                try {
                  await (await SharedPreferences.getInstance()).setInt(_tabKey, i);
                } catch (_) {}
              },
              tabs: [Tab(text: l.bundleTabClassic), Tab(text: l.bundleTabGenre), Tab(text: l.bundleTabMine)],
            ),
            Expanded(
              child: TabBarView(children: [
                for (final g in _groups)
                  if (g == 'mine') _mineList(l) else _list([for (final b in widget.catalog) if ((b['group'] ?? 'genre') == g) b], guide: g == 'genre'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> bundles, {bool guide = false}) {
    final l = AppLocalizations.of(context)!;
    return ListView(padding: const EdgeInsets.only(bottom: 12), children: [
      for (final b in bundles) _BundleCard(bundle: b, onPick: (adjust) => Navigator.pop(context, (_specOf(b), adjust))),
      if (guide)
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(l.guideTitle),
          subtitle: Text(l.guideDesc),
          onTap: () async {
            final spec = await BundleService.loadGuide(widget.locale);
            if (mounted) Navigator.pop(context, (spec, false));
          },
        ),
    ]);
  }

  Widget _mineList(AppLocalizations l) {
    if (_mine.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.bundleMineEmpty, textAlign: TextAlign.center, style: TextStyle(color: context.ddx.textMuted)),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 12), children: [
      for (final b in _mine)
        _BundleCard(
          bundle: b,
          onPick: (adjust) => Navigator.pop(context, (_specOf(b), adjust)),
          onDelete: () async {
            final container = ProviderScope.containerOf(context);
            if (!await showConfirmDialog(context, message: l.presetDeleteConfirm)) return;
            final db = await container.read(databaseProvider.future);
            await db.rawDelete('DELETE FROM module_preset WHERE id=?', [int.parse('${b['id']}'.substring(2))]);
            setState(() => _mine.remove(b));
          },
        ),
    ]);
  }
}

class _BundleCard extends StatelessWidget {
  final Map<String, dynamic> bundle;
  final void Function(bool adjustFirst) onPick;
  final VoidCallback? onDelete;
  const _BundleCard({required this.bundle, required this.onPick, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final spec = (bundle['spec'] as Map?) ?? const {};
    final kinds = <ModuleKind>{
      for (final m in (spec['modules'] as List?) ?? const [])
        if (m is Map && m['kind'] is String) ModuleKind.fromId(m['kind'] as String),
    };
    final samples = BundleService.hasSamples(spec);
    final desc = '${bundle['description'] ?? ''}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPick(false),
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${bundle['name']}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.ddx.textMuted)),
                  ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  for (final k in kinds) Icon(moduleKindInfo[k]!.icon, size: 16, color: context.ddx.textMuted),
                  if (samples)
                    Text('· ${l.bundleSampleCount}', style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
                ]),
              ]),
            ),
            IconButton(tooltip: l.bundleAdjust, icon: const Icon(Icons.tune), onPressed: () => onPick(true)),
          ]),
        ),
      ),
    );
  }
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

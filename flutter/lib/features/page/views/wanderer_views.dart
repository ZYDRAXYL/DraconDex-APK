import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../hub/content/wanderer_content.dart';
import '../component_registry.dart';
import 'graph_view.dart';
import '../kind_views.dart';
import 'view_common.dart';

/// The Wanderer's three presets (EXE mod/wanderer.js WANDERER_VIEWS): map
/// (its pins), area (the referenced Locator's areas and which pins stand in
/// each) and timeline (the pins in the order their events happen).

class _Pin {
  final int id;
  final String label;
  final int? areaRef;
  final String? date;
  final int? ord;
  const _Pin(this.id, this.label, this.areaRef, this.date, this.ord);
}

class _WandererData {
  final List<_Pin> pins;
  final int? locator;
  final List<(int, String)> locators;
  final List<(int, String, String?)> areas; // id, name, colour
  const _WandererData(this.pins, this.locator, this.locators, this.areas);
}

final _wandererProvider = FutureProvider.autoDispose.family<_WandererData, (int, int)>((ref, arg) async {
  final (moduleId, nexusId) = arg;
  ref.watch(mapPinsProvider(moduleId));
  final db = await ref.watch(databaseProvider.future);
  final pins = await db.rawQuery('''
    SELECT me.id, me.label, me.area_ref, te.event_name, s.day, s.month, s.years, s.hour, s.minute
      FROM map_event me
      LEFT JOIN timeline_event te ON me.event_ref = te.id
      LEFT JOIN timeline_date s ON te.start_at = s.id
     WHERE me.module_ref = ? ORDER BY me.id''', [moduleId]);
  final locators = await db.rawQuery(
      "SELECT id, name FROM module WHERE nexus_ref=? AND kind='locator' ORDER BY name COLLATE NOCASE", [nexusId]);
  final ui = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='mapModule'", [moduleId]);
  final loc = ui.isEmpty ? null : int.tryParse(ui.first['ui_value'] as String? ?? '');
  final areas = loc == null
      ? const <Map<String, Object?>>[]
      : await db.rawQuery('''
          SELECT a.id, a.area_name, uc.color_code FROM map_area a JOIN map m ON a.map_id = m.id
          LEFT JOIN use_color uc ON a.color = uc.id WHERE m.module_ref = ? ORDER BY a.id''', [loc]);
  return _WandererData(
    [
      for (final p in pins)
        _Pin(
          p['id'] as int,
          (p['label'] as String?)?.isNotEmpty == true ? p['label'] as String : (p['event_name'] as String? ?? '—'),
          p['area_ref'] as int?,
          p['years'] == null ? null : '${p['day']}/${p['month']}/${p['years']}',
          p['years'] == null
              ? null
              : ((((p['years'] as int) * 13 + (p['month'] as int)) * 32 + (p['day'] as int)) * 24 + (p['hour'] as int? ?? 0)) * 60 +
                  (p['minute'] as int? ?? 0),
        ),
    ],
    locators.any((r) => r['id'] == loc) ? loc : null,
    [for (final r in locators) (r['id'] as int, r['name'] as String)],
    [for (final a in areas) (a['id'] as int, a['area_name'] as String? ?? '—', a['color_code'] as String?)],
  );
});

class WandererView extends ConsumerWidget {
  final ComponentCtx ctx;
  const WandererView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ctx.preset == 'map' || ctx.preset.isEmpty) return WandererContent(moduleId: ctx.source.id, nexusId: ctx.nexusId, boardHeight: fullBoard(context, ctx));
    final l = AppLocalizations.of(context)!;
    final arg = (ctx.source.id, ctx.nexusId);
    final d = ref.watch(_wandererProvider(arg)).valueOrNull;
    if (d == null) return const SizedBox(height: 48);
    if (ctx.preset == 'timeline') {
      final ordered = [...d.pins]..sort((a, b) => (a.ord ?? 1 << 62).compareTo(b.ord ?? 1 << 62));
      if (ordered.isEmpty) return EmptyHint(l.wandererNoPins);
      return Column(children: [
        for (final p in ordered)
          ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, size: 20),
            title: Text(p.label),
            trailing: Text(p.date ?? l.wandererNoLink, style: Theme.of(context).textTheme.labelSmall),
          ),
      ]);
    }
    // area
    Future<void> setLocator(int? v) async {
      final db = await ref.read(databaseProvider.future);
      await db.insert('module_ui', {'module_ref': ctx.source.id, 'ui_key': 'mapModule', 'ui_value': '${v ?? ''}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      ref.invalidate(_wandererProvider(arg));
    }

    Future<void> setArea(int pin, int? area) async {
      final db = await ref.read(databaseProvider.future);
      await db.rawUpdate("UPDATE map_event SET area_ref=?, update_at=datetime('now') WHERE id=?", [area, pin]);
      ref.invalidate(mapPinsProvider(ctx.source.id));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonFormField<int>(
          initialValue: d.locator,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.wndLocator, isDense: true),
          items: [for (final (id, name) in d.locators) DropdownMenuItem(value: id, child: Text(name))],
          onChanged: setLocator,
        ),
      ),
      if (d.locator == null)
        EmptyHint(d.locators.isEmpty ? l.wndNoLocator : l.wndPickLocator)
      else if (d.areas.isEmpty)
        EmptyHint(l.wndNoAreas)
      else
        for (final (aid, name, color) in d.areas)
          ExpansionTile(
            leading: Icon(Icons.circle, size: 12, color: hexColor(color) ?? Theme.of(context).colorScheme.primary),
            title: Text(name),
            subtitle: Text('${d.pins.where((p) => p.areaRef == aid).length}'),
            children: [
              for (final p in d.pins.where((p) => p.areaRef == aid))
                ListTile(
                  dense: true,
                  title: Text(p.label),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: l.btnDelete,
                    onPressed: () => setArea(p.id, null),
                  ),
                ),
              if (d.pins.any((p) => p.areaRef != aid))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add),
                  title: Text(l.wndAddPin),
                  onTap: () async {
                    final pick = await showDialog<int>(
                      context: context,
                      builder: (dc) => SimpleDialog(title: Text(name), children: [
                        for (final p in d.pins.where((p) => p.areaRef != aid))
                          SimpleDialogOption(onPressed: () => Navigator.pop(dc, p.id), child: Text(p.label)),
                      ]),
                    );
                    if (pick != null) await setArea(pick, aid);
                  },
                ),
            ],
          ),
    ]);
  }
}

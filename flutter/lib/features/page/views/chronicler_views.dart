import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/chronicler_dao.dart';
import '../../../data/models/chronicler_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../hub/content/chronicler_content.dart';
import '../component_registry.dart';
import 'graph_view.dart';
import 'view_common.dart';

/// The Chronicler's four presets (EXE mod/chronicler.js CHRONICLER_VIEWS):
/// oneline, downline, compare, calendar. Dates stay calendar-agnostic
/// integers (a Nexus may run on an invented calendar), so positions come
/// from an ordinal that only needs to be monotonic, not a real day count.

int dateOrdinal(TimelineDateModel d) => (((d.years * 13 + d.month) * 32 + d.day) * 24 + d.hour) * 60 + d.minute;

/// The desktop's fmtDate: D/M/Y, the time only when there is one.
String fmtDate(TimelineDateModel d) {
  final t = (d.hour != 0 || d.minute != 0) ? ' ${'${d.hour}'.padLeft(2, '0')}:${'${d.minute}'.padLeft(2, '0')}' : '';
  return '${d.day}/${d.month}/${d.years}$t';
}

/// Another module's line (Compare).
final _eventsOfModuleProvider = FutureProvider.autoDispose.family<List<TimelineEventModel>, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final dao = ChroniclerDao(db);
  return dao.getEvents(await dao.ensureTimeline(moduleId));
});

class ChroniclerView extends ConsumerWidget {
  final ComponentCtx ctx;
  const ChroniclerView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ctx.source.id;
    // Every view shares the line's add/edit list (ChroniclerContent); a
    // write there refreshes the drawings through timelineEventsProvider.
    final tl = ref.watch(timelineProvider(id)).valueOrNull;
    final evs = tl == null ? null : ref.watch(timelineEventsProvider(tl)).valueOrNull;
    if (evs == null) return const SizedBox(height: 48);
    final Widget graph = switch (ctx.preset) {
      'downline' => _Downline(ctx: ctx, evs: evs),
      'compare' => _Compare(ctx: ctx, evs: evs),
      'calendar' => _Calendar(ctx: ctx, evs: evs),
      _ => _Oneline(ctx: ctx, evs: evs),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (evs.isNotEmpty || ctx.preset == 'compare') graph,
      if (ctx.preset != 'calendar') ChroniclerContent(moduleId: id),
    ]);
  }
}

void _open(BuildContext context, ComponentCtx ctx, TimelineEventModel e) =>
    openElement(context, ctx.nexusId, ctx.source.id, 'tlev_${e.id}');

/// One horizontal line on a true time scale; labels alternate above and
/// below so neighbours do not overwrite each other.
class _Oneline extends StatelessWidget {
  final ComponentCtx ctx;
  final List<TimelineEventModel> evs;
  const _Oneline({required this.ctx, required this.evs});

  @override
  Widget build(BuildContext context) => _Track(ctx: ctx, lines: [(evs, hexColor(ctx.source.colorCode))]);
}

class _Compare extends ConsumerWidget {
  final ComponentCtx ctx;
  final List<TimelineEventModel> evs;
  const _Compare({required this.ctx, required this.evs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final others = ref.watch(_otherLinesProvider((ctx.source.id, ctx.nexusId))).valueOrNull;
    if (others == null) return const SizedBox(height: 48);
    final pick = others.$1;
    final picker = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<int>(
        initialValue: pick,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.chrCompareWith, isDense: true),
        items: [for (final (id, name) in others.$2) DropdownMenuItem(value: id, child: Text(name))],
        onChanged: (v) async {
          if (v == null) return;
          final db = await ref.read(databaseProvider.future);
          await db.insert('module_ui', {'module_ref': ctx.source.id, 'ui_key': 'compareWith', 'ui_value': '$v'},
              conflictAlgorithm: ConflictAlgorithm.replace);
          ref.invalidate(_otherLinesProvider((ctx.source.id, ctx.nexusId)));
        },
      ),
    );
    if (others.$2.isEmpty) return EmptyHint(l.chrNoOtherLine);
    if (pick == null) return picker;
    final b = ref.watch(_eventsOfModuleProvider(pick)).valueOrNull ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      picker,
      _Track(ctx: ctx, lines: [(evs, hexColor(ctx.source.colorCode)), (b, const Color(0xFFF97316))]),
    ]);
  }
}

/// (the module compared with, [(id, name)] of the Nexus's other Chroniclers).
final _otherLinesProvider = FutureProvider.autoDispose.family<(int?, List<(int, String)>), (int, int)>((ref, arg) async {
  final (moduleId, nexusId) = arg;
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.rawQuery(
      "SELECT id, name FROM module WHERE nexus_ref=? AND kind='chronicler' AND id<>? ORDER BY name COLLATE NOCASE", [nexusId, moduleId]);
  final ui = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='compareWith'", [moduleId]);
  final list = [for (final r in rows) (r['id'] as int, r['name'] as String)];
  final saved = ui.isEmpty ? null : int.tryParse(ui.first['ui_value'] as String? ?? '');
  return (list.any((x) => x.$1 == saved) ? saved : null, list);
});

/// One or two horizontal lines on a shared time scale. With two, dashed
/// links join events on the very same date (the same timeline_date row).
class _Track extends StatelessWidget {
  final ComponentCtx ctx;
  final List<(List<TimelineEventModel>, Color?)> lines;
  const _Track({required this.ctx, required this.lines});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = [for (final (e, _) in lines) ...e];
    if (all.isEmpty) return const SizedBox.shrink();
    final ts = [for (final e in all) dateOrdinal(e.start)];
    final min = ts.reduce(math.min), max = ts.reduce(math.max);
    final span = math.max(1, max - min);
    const margin = 60.0;
    final maxCount = lines.map((l) => l.$1.length).reduce(math.max);
    return LayoutBuilder(builder: (context, box) {
      final width = math.max(box.maxWidth, maxCount * 90.0 + 2 * margin);
      final usable = width - 2 * margin;
      final lineGap = 150.0;
      final height = 60.0 + lineGap * lines.length;
      double xOf(TimelineEventModel e) => margin + (dateOrdinal(e.start) - min) / span * usable;
      double yOf(int line) => 75.0 + lineGap * line;
      final dots = <Widget>[];
      for (var li = 0; li < lines.length; li++) {
        final (evs, color) = lines[li];
        for (var i = 0; i < evs.length; i++) {
          final e = evs[i];
          final above = i.isEven;
          final x = xOf(e), y = yOf(li);
          dots.add(Positioned(
            left: x - 60,
            top: above ? y - 58 : y - 8,
            width: 120,
            height: 66,
            child: GestureDetector(
              onTap: () => li == 0 ? _open(context, ctx, e) : null,
              child: Column(
                mainAxisAlignment: above ? MainAxisAlignment.start : MainAxisAlignment.end,
                verticalDirection: above ? VerticalDirection.down : VerticalDirection.up,
                children: [
                  Text(e.name?.isNotEmpty == true ? e.name! : '—',
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  Text(fmtDate(e.start), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: hexColor(e.colorCode) ?? color ?? scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ));
        }
      }
      final links = <(Offset, Offset)>[];
      if (lines.length == 2) {
        for (final a in lines[0].$1) {
          for (final b in lines[1].$1) {
            if (a.start.id == b.start.id) links.add((Offset(xOf(a), yOf(0)), Offset(xOf(b), yOf(1))));
          }
        }
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TrackPainter([for (var i = 0; i < lines.length; i++) yOf(i)], margin, width - margin, links, scheme),
              ),
            ),
            ...dots,
          ]),
        ),
      );
    });
  }
}

class _TrackPainter extends CustomPainter {
  final List<double> ys;
  final double x0, x1;
  final List<(Offset, Offset)> links;
  final ColorScheme scheme;
  _TrackPainter(this.ys, this.x0, this.x1, this.links, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final y in ys) {
      canvas.drawLine(Offset(x0, y), Offset(x1, y), line);
    }
    final dash = Paint()
      ..color = scheme.primary
      ..strokeWidth = 2;
    for (final (a, b) in links) {
      final d = b - a;
      final n = (d.distance / 9).floor();
      for (var i = 0; i < n; i += 2) {
        canvas.drawLine(a + d * (i / n), a + d * ((i + 1) / n), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}

/// Top to bottom on a true time scale — the phone's natural direction.
class _Downline extends StatelessWidget {
  final ComponentCtx ctx;
  final List<TimelineEventModel> evs;
  const _Downline({required this.ctx, required this.evs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const top = 26.0, lineX = 40.0;
    final h = math.max(360.0, math.min(720.0, evs.length * 96.0));
    final ts = [for (final e in evs) dateOrdinal(e.start)];
    final min = ts.reduce(math.min), span = math.max(1, ts.reduce(math.max) - min);
    // Evenly spread when crowded: true scale, but never two labels on one row.
    final ys = <double>[];
    for (final e in evs) {
      var y = top + (dateOrdinal(e.start) - min) / span * (h - 2 * top);
      if (ys.isNotEmpty && y < ys.last + 22) y = ys.last + 22;
      ys.add(y);
    }
    final height = math.max(h, (ys.isEmpty ? 0 : ys.last) + top);
    return SizedBox(
      height: height,
      child: Stack(children: [
        Positioned(left: lineX - 1, top: top - 10, bottom: top - 10, child: Container(width: 2, color: scheme.outlineVariant)),
        for (var i = 0; i < evs.length; i++)
          Positioned(
            left: lineX - 7,
            right: 16,
            top: ys[i] - 9,
            child: InkWell(
              onTap: () => _open(context, ctx, evs[i]),
              child: Row(children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: hexColor(evs[i].colorCode) ?? scheme.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${evs[i].name?.isNotEmpty == true ? evs[i].name! : '—'}  ·  ${fmtDate(evs[i].start)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A month at a time. The desktop's custom calendars (module_ui
/// calendarConfig) are not read here yet: a month shows as many days as the
/// longest of 30 or its latest event, with no weekday header — nothing that
/// assumes the Gregorian calendar.
class _Calendar extends StatefulWidget {
  final ComponentCtx ctx;
  final List<TimelineEventModel> evs;
  const _Calendar({required this.ctx, required this.evs});

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  late int _y = widget.evs.isEmpty ? 1 : widget.evs.first.start.years;
  late int _m = widget.evs.isEmpty ? 1 : widget.evs.first.start.month;

  int get _monthsPerYear => math.max(12, widget.evs.fold(0, (a, e) => math.max(a, e.start.month)));

  void _step(int d) => setState(() {
        _m += d;
        if (_m < 1) {
          _m = _monthsPerYear;
          _y--;
        } else if (_m > _monthsPerYear) {
          _m = 1;
          _y++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inMonth = [for (final e in widget.evs) if (e.start.years == _y && e.start.month == _m) e];
    final days = math.max(30, inMonth.fold(0, (a, e) => math.max(a, e.start.day)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _step(-1)),
        Text('$_m / $_y', style: theme.textTheme.titleMedium),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _step(1)),
      ]),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        childAspectRatio: 0.8,
        children: [
          for (var d = 1; d <= days; d++)
            Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$d', style: theme.textTheme.labelSmall),
                for (final e in inMonth.where((e) => e.start.day == d).take(2))
                  GestureDetector(
                    onTap: () => _open(context, widget.ctx, e),
                    child: Container(
                      margin: const EdgeInsets.only(top: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: hexColor(e.colorCode) ?? theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(e.name ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(fontSize: 9, color: theme.colorScheme.onPrimary)),
                    ),
                  ),
                if (inMonth.where((e) => e.start.day == d).length > 2)
                  Text('+${inMonth.where((e) => e.start.day == d).length - 2}', style: const TextStyle(fontSize: 9)),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final e in inMonth)
        ListTile(dense: true, title: Text(e.name ?? '—'), subtitle: Text(fmtDate(e.start)), onTap: () => _open(context, widget.ctx, e)),
    ]);
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/sketcher_dao.dart';
import '../../../data/models/sketcher_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/row_menu.dart';
import '../../hub/content/sketcher_content.dart';
import '../component_registry.dart';
import '../kind_views.dart';
import 'view_common.dart';

/// The Sketcher's four presets (EXE mod/sketcher.js SKETCHER_VIEWS): canvas,
/// pages, gallery, export (a page as a PNG, shared).

/// The desktop's page background (sketcher.js / sketch-render.js).
const _paper = Color(0xFF0B0B10);

Color _hex(String? c) {
  final h = (c ?? '').replaceFirst('#', '');
  final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
  return v == null ? const Color(0xFFE879F9) : Color(0xFF000000 | v);
}

void paintStrokes(Canvas canvas, List<SketchStrokeModel> strokes) {
  for (final s in strokes) {
    if (s.points.length < 4) continue;
    final path = Path()..moveTo(s.points[0], s.points[1]);
    for (var i = 2; i + 1 < s.points.length; i += 2) {
      path.lineTo(s.points[i], s.points[i + 1]);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _hex(s.color)
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

class _StrokesPainter extends CustomPainter {
  final List<SketchStrokeModel> strokes;
  _StrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    paintStrokes(canvas, strokes);
  }

  @override
  bool shouldRepaint(_StrokesPainter old) => old.strokes != strokes;
}

/// A page drawn small, at the page's own aspect.
class SketchThumb extends ConsumerWidget {
  final int pageId;
  const SketchThumb({super.key, required this.pageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strokes = ref.watch(sketchStrokesProvider(pageId)).valueOrNull ?? const <SketchStrokeModel>[];
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: kSketchWidth,
        height: kSketchHeight,
        child: CustomPaint(painter: _StrokesPainter(strokes)),
      ),
    );
  }
}

/// A page as PNG bytes at [scale] of its 1600×1100 size.
Future<List<int>> sketchPng(List<SketchStrokeModel> strokes, {double scale = 1}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(scale);
  c.drawRect(const Rect.fromLTWH(0, 0, kSketchWidth, kSketchHeight), Paint()..color = _paper);
  paintStrokes(c, strokes);
  final img = await rec.endRecording().toImage((kSketchWidth * scale).round(), (kSketchHeight * scale).round());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class SketcherView extends ConsumerWidget {
  final ComponentCtx ctx;
  const SketcherView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final id = ctx.source.id;
    if (ctx.preset == 'canvas' || ctx.preset.isEmpty) return SketcherContent(moduleId: id, boardHeight: fullBoard(context, ctx));
    final pages = ref.watch(sketchPagesProvider(id)).valueOrNull;
    if (pages == null) return const SizedBox(height: 48);
    final bar = ViewBar(actions: [
      IconButton(
        tooltip: l.sketcherNewPage,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final name = await askText(context, l.sketcherNewPage, label: l.labelName);
          if (name == null) return;
          final db = await ref.read(databaseProvider.future);
          await SketcherDao(db).createPage(moduleRef: id, name: name);
          ref.invalidate(sketchPagesProvider(id));
          ref.invalidate(nexusIndexProvider(ctx.nexusId));
        },
      ),
    ]);
    if (pages.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, EmptyHint(l.sketcherNoPages)]);
    final body = switch (ctx.preset) {
      'gallery' => _Gallery(ctx: ctx, pages: pages),
      'export' => _Export(ctx: ctx, pages: pages),
      _ => _Pages(ctx: ctx, pages: pages),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, body]);
  }
}

void _pageMenu(BuildContext context, WidgetRef ref, ComponentCtx ctx, SketchPageModel p) {
  final l = AppLocalizations.of(context)!;
  showRowMenu(context, title: p.name, [
    RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'skpg_${p.id}')),
    RowAction(
      label: l.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        final name = await askText(context, l.btnRename, initial: p.name, label: l.labelName);
        if (name == null) return;
        final db = await ref.read(databaseProvider.future);
        await SketcherDao(db).renamePage(p.id, name);
        ref.invalidate(sketchPagesProvider(ctx.source.id));
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
    RowAction(
      label: l.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () async {
        if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
        final db = await ref.read(databaseProvider.future);
        await SketcherDao(db).deletePage(p.id);
        ref.invalidate(sketchPagesProvider(ctx.source.id));
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
  ]);
}

/// Pages in order; drag to reorder.
class _Pages extends ConsumerWidget {
  final ComponentCtx ctx;
  final List<SketchPageModel> pages;
  const _Pages({required this.ctx, required this.pages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) async {
        final ids = [for (final p in pages) p.id];
        ids.insert(to, ids.removeAt(from));
        final db = await ref.read(databaseProvider.future);
        await SketcherDao(db).reorderPages(ids);
        ref.invalidate(sketchPagesProvider(ctx.source.id));
      },
      children: [
        for (var i = 0; i < pages.length; i++)
          ListTile(
            key: ValueKey(pages[i].id),
            leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
            title: Text('${i + 1}. ${pages[i].name}'),
            trailing: SizedBox(width: 64, height: 44, child: SketchThumb(pageId: pages[i].id)),
            onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'skpg_${pages[i].id}'),
            onLongPress: () => _pageMenu(context, ref, ctx, pages[i]),
          ),
      ],
    );
  }
}

class _Gallery extends ConsumerWidget {
  final ComponentCtx ctx;
  final List<SketchPageModel> pages;
  const _Gallery({required this.ctx, required this.pages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      children: [
        for (var i = 0; i < pages.length; i++)
          InkWell(
            onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'skpg_${pages[i].id}'),
            onLongPress: () => _pageMenu(context, ref, ctx, pages[i]),
            child: Column(children: [
              Expanded(
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: SketchThumb(pageId: pages[i].id)),
              ),
              Text('${i + 1}. ${pages[i].name}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
      ],
    );
  }
}

/// One page, large, and a button that shares it as a PNG.
class _Export extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  final List<SketchPageModel> pages;
  const _Export({required this.ctx, required this.pages});

  @override
  ConsumerState<_Export> createState() => _ExportState();
}

class _ExportState extends ConsumerState<_Export> {
  int? _page;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = widget.pages.where((x) => x.id == _page).firstOrNull ?? widget.pages.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButton<int>(
          value: p.id,
          isExpanded: true,
          items: [for (final x in widget.pages) DropdownMenuItem(value: x.id, child: Text(x.name))],
          onChanged: (v) => setState(() => _page = v),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: kSketchWidth / kSketchHeight,
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SketchThumb(pageId: p.id)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final strokes = await ref.read(sketchStrokesProvider(p.id).future);
                    final png = await sketchPng(strokes);
                    await Share.shareXFiles([
                      XFile.fromData(Uint8List.fromList(png), mimeType: 'image/png', name: '${p.name}.png'),
                    ]);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          icon: const Icon(Icons.ios_share),
          label: Text('${l.skExportPng} — ${p.name}'),
        ),
      ]),
    );
  }
}

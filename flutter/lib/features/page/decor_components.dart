import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../tools/assets_screen.dart';
import 'block_options.dart';
import 'component_registry.dart';
import 'links.dart';
import 'media_components.dart' show fileIdOf;
import 'page_providers.dart';

/// Decoration on the phone (Procress 14, APP docs/EXPORT-DECOR.md D2; EXE
/// renderer/page/components/decor.js): a banner, a gallery, a divider, a
/// row of icons and a figure, reading the desktop's own options. Pictures
/// come from the Nest — the stored file, or its proxy on the web.
final List<ComponentDef> decorComponents = [
  ComponentDef(id: 'core.banner', kind: null, label: (l) => l.pcBanner, build: (c, x) => _Banner(ctx: x)),
  ComponentDef(id: 'core.gallery', kind: null, label: (l) => l.pcGallery, build: (c, x) => _Gallery(ctx: x)),
  ComponentDef(id: 'core.divider', kind: null, label: (l) => l.pcDivider, build: (c, x) => DecorDivider(opts: (k) => optValue(x.block, k), nexusId: x.nexusId)),
  ComponentDef(id: 'core.iconrow', kind: null, label: (l) => l.pcIconrow, build: (c, x) => _IconRow(ctx: x)),
  ComponentDef(id: 'core.figure', kind: null, label: (l) => l.pcFigure, build: (c, x) => _Figure(ctx: x)),
];

Widget _hint(BuildContext context, WidgetRef ref, ComponentCtx ctx, String text) {
  final l10n = AppLocalizations.of(context)!;
  return Text(ref.watch(arrangeModeProvider(ctx.key)) ? l10n.pcDecorPickArrange : text, style: TextStyle(color: context.ddx.textMuted));
}

/// The best bytes to draw for a Nest picture.
Uint8List? _pic(WidgetRef ref, int? id) => id == null ? null : ref.watch(assetBytesProvider(id)).valueOrNull;

Widget _imageOr(Uint8List? b, Widget Function(Uint8List) draw, Widget otherwise) => b == null ? otherwise : draw(b);

/// Where a picture keeps its subject when cropped — the desktop's focal
/// point, {x, y} percentages.
Alignment focusOf(Object? v) {
  if (v is! Map) return Alignment.center;
  final x = (v['x'] as num?)?.toDouble(), y = (v['y'] as num?)?.toDouble();
  if (x == null || y == null) return Alignment.center;
  return Alignment((x.clamp(0, 100) / 50) - 1, (y.clamp(0, 100) / 50) - 1);
}

/// One picture at a time, full screen, swiped.
Future<void> openLightbox(BuildContext context, List<int> ids, int start) => Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _Lightbox(ids: ids, start: start),
      ),
    );

class _Lightbox extends ConsumerWidget {
  final List<int> ids;
  final int start;
  const _Lightbox({required this.ids, required this.start});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: PageView(
          controller: PageController(initialPage: start),
          children: [
            for (final id in ids)
              InteractiveViewer(
                maxScale: 6,
                child: Center(child: _imageOr(_pic(ref, id), (b) => Image.memory(b, gaplessPlayback: true), const CircularProgressIndicator())),
              ),
          ],
        ),
      );
}

// ── banner ──────────────────────────────────────────────────────────────
class _Banner extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Banner({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final id = fileIdOf(optValue(ctx.block, 'image'));
    if (id == null) return _hint(context, ref, ctx, l10n.pcBannerEmpty);
    final bytes = _pic(ref, id);
    final title = '${optValue(ctx.block, 'title') ?? ''}';
    final sub = '${optValue(ctx.block, 'sub') ?? ''}';
    final h = switch (optValue(ctx.block, 'height')) { 's' => 140.0, 'l' => 300.0, _ => 210.0 };
    final center = optValue(ctx.block, 'align') == 'center';
    // the scrim reaches the darkness white text needs before the text starts
    final strong = optValue(ctx.block, 'scrim') == 'strong';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: h,
        child: Stack(fit: StackFit.expand, children: [
          if (bytes != null) Image.memory(bytes, fit: BoxFit.cover, alignment: focusOf(optValue(ctx.block, 'focus')), gaplessPlayback: true)
          else ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          if (title.isNotEmpty || sub.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .45, 1],
                  colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, strong ? .6 : .55), Color.fromRGBO(0, 0, 0, strong ? .8 : .7)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title, textAlign: center ? TextAlign.center : TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    if (sub.isNotEmpty) Text(sub, textAlign: center ? TextAlign.center : TextAlign.left, style: const TextStyle(color: Color(0xFFF4F4F8))),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── gallery ─────────────────────────────────────────────────────────────
final _moduleImagesProvider = FutureProvider.autoDispose.family<List<int>, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.rawQuery(
      "SELECT id FROM import_file WHERE module_ref=? AND source_kind='file' AND lower(file_type) IN ('png','jpg','jpeg','gif','webp') ORDER BY id", [moduleId]);
  return [for (final r in rows) r['id'] as int];
});

class _Gallery extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Gallery({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ids = optValue(ctx.block, 'fromModule') == true
        ? (ref.watch(_moduleImagesProvider(ctx.page.module.id)).valueOrNull ?? const <int>[])
        : [for (final r in (optValue(ctx.block, 'images') as List?) ?? const []) ?fileIdOf(r)];
    if (ids.isEmpty) return _hint(context, ref, ctx, l10n.pcGalleryEmpty);
    final strip = optValue(ctx.block, 'layout') == 'strip';
    final names = {for (final a in ref.watch(assetsProvider(ctx.nexusId)).valueOrNull ?? const []) a.id: a.name};
    final captions = optValue(ctx.block, 'captions') == true;
    Widget tile(int i, double w) => GestureDetector(
          onTap: () => openLightbox(context, ids, i),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: w,
                height: w,
                child: _imageOr(_pic(ref, ids[i]), (b) => Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true),
                    ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)),
              ),
            ),
            if (captions && (names[ids[i]] ?? '').isNotEmpty)
              SizedBox(width: w, child: Text(names[ids[i]]!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          ]),
        );
    if (strip) {
      return SizedBox(
        height: captions ? 150 : 132,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < ids.length; i++) Padding(padding: const EdgeInsets.only(right: 6), child: tile(i, 130)),
        ]),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      final want = int.tryParse('${optValue(ctx.block, 'cols')}') ?? 3;
      final n = box.maxWidth < 400 ? want.clamp(2, 3) : want;
      final w = (box.maxWidth - 6 * (n - 1)) / n;
      return Wrap(spacing: 6, runSpacing: 6, children: [for (var i = 0; i < ids.length; i++) tile(i, w)]);
    });
  }
}

// ── divider ─────────────────────────────────────────────────────────────
/// A line, two, dots, an ornament, or a thin band of picture — the plain
/// `divider` block draws through this too, so its options apply there.
class DecorDivider extends ConsumerWidget {
  final Object? Function(String key) opts;
  final int nexusId;
  const DecorDivider({super.key, required this.opts, required this.nexusId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).dividerColor;
    switch ('${opts('look') ?? 'line'}') {
      case 'double':
        return Column(children: [Divider(color: color, height: 6), Divider(color: color, height: 6)]);
      case 'dots':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(child: Text('•  •  •', style: TextStyle(color: context.ddx.textMuted, letterSpacing: 4))),
        );
      case 'ornament':
        final icon = '${opts('icon') ?? ''}';
        return Row(children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(icon.startsWith('sym:') ? icon.substring(4) : '✦', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16)),
          ),
          Expanded(child: Divider(color: color)),
        ]);
      case 'image':
        final b = _pic(ref, fileIdOf(opts('image')));
        if (b != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(height: 36, width: double.infinity, child: Image.memory(b, fit: BoxFit.cover, alignment: focusOf(opts('focus')))),
          );
        }
        return Divider(color: color);
      default:
        return Divider(color: color);
    }
  }
}

// ── icon row ────────────────────────────────────────────────────────────
class _IconRow extends ConsumerWidget {
  final ComponentCtx ctx;
  const _IconRow({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final raw = ctx.block.config['opts'] is Map ? (ctx.block.config['opts'] as Map)['items'] : ctx.block.config['items'];
    final items = [
      for (final it in raw is List ? raw : const [])
        if (it is Map && ('${it['icon'] ?? ''}'.isNotEmpty || '${it['label'] ?? ''}'.isNotEmpty)) ('${it['icon'] ?? ''}', '${it['label'] ?? ''}'),
    ];
    if (items.isEmpty) return _hint(context, ref, ctx, l10n.pcIconrowEmpty);
    final big = optValue(ctx.block, 'look') == 'big';
    final size = switch (optValue(ctx.block, 'size')) { 's' => 14.0, 'l' => 22.0, _ => 18.0 };
    // an icon the phone has no drawing of (a desktop svg: key) leaves the word
    String glyph(String icon) => icon.startsWith('sym:') ? icon.substring(4) : '';
    if (big) {
      return Wrap(spacing: 16, runSpacing: 12, children: [
        for (final (icon, label) in items)
          SizedBox(
            width: 72,
            child: Column(children: [
              if (glyph(icon).isNotEmpty) Text(glyph(icon), style: TextStyle(fontSize: size * 1.8)),
              if (label.isNotEmpty) Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ]),
          ),
      ]);
    }
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (icon, label) in items)
        Chip(
          avatar: glyph(icon).isEmpty ? null : Text(glyph(icon), style: TextStyle(fontSize: size)),
          label: Text(label.isEmpty ? glyph(icon) : label),
          visualDensity: VisualDensity.compact,
        ),
    ]);
  }
}

// ── figure ──────────────────────────────────────────────────────────────
class _Figure extends ConsumerWidget {
  final ComponentCtx ctx;
  const _Figure({required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final id = fileIdOf(optValue(ctx.block, 'image'));
    if (id == null) return _hint(context, ref, ctx, l10n.pcFigureEmpty);
    final b = _pic(ref, id);
    final frac = switch (optValue(ctx.block, 'size')) { 's' => .33, 'm' => .5, 'l' => .75, _ => 1.0 };
    final cover = optValue(ctx.block, 'fit') == 'cover';
    final round = optValue(ctx.block, 'round') != false;
    final caption = '${optValue(ctx.block, 'caption') ?? ''}';
    final link = linksFrom(optValue(ctx.block, 'links')).firstOrNull;
    final index = ref.watch(nexusIndexProvider(ctx.nexusId)).valueOrNull;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth * frac;
      return Align(
        // float left / right has no room beside it on a phone: it aligns
        alignment: switch (optValue(ctx.block, 'float')) { 'left' => Alignment.centerLeft, 'right' => Alignment.centerRight, _ => Alignment.center },
        child: SizedBox(
          width: w,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GestureDetector(
              onTap: () => link != null ? followLink(context, ref, link, resolveLink(link, index), ctx.nexusId) : openLightbox(context, [id], 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(round ? 10 : 0),
                child: b == null
                    ? AspectRatio(aspectRatio: 4 / 3, child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest))
                    : cover
                        ? AspectRatio(aspectRatio: 4 / 3, child: Image.memory(b, fit: BoxFit.cover, alignment: focusOf(optValue(ctx.block, 'focus'))))
                        : Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(caption, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.ddx.textMuted)),
              ),
          ]),
        ),
      );
    });
  }
}

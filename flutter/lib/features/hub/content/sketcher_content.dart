import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/sketcher_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Sketcher kind: freehand drawing pages.
///
/// The surface is the desktop's fixed 1600x1100 space, so coordinates mean
/// the same thing on both front-ends, and strokes are written in the desktop's
/// flat [x0,y0,x1,y1,...] encoding.
///
/// One thing the desktop does not have to solve: on a touch screen, drawing
/// and panning are the same gesture. A draw/pan toggle decides which one the
/// finger does, rather than guessing and getting it wrong half the time.
class SketcherContent extends ConsumerStatefulWidget {
  final int moduleId;
  /// The board's height: 360 on a page, the screen's in full screen.
  final double boardHeight;

  const SketcherContent({super.key, required this.moduleId, this.boardHeight = 360});

  @override
  ConsumerState<SketcherContent> createState() => _SketcherContentState();
}

class _SketcherContentState extends ConsumerState<SketcherContent> {
  int? _pageId;
  bool _drawMode = true;
  String _color = kSketchColors[0];
  double _width = kSketchWidths[1];

  /// The stroke under the finger, in board coordinates. Kept out of the
  /// database until the gesture ends.
  List<double> _current = [];

  Future<void> _addPage() async {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.read(sketcherDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createPage(moduleRef: widget.moduleId, name: l10n.sketcherNewPage);
    if (!mounted) return;
    setState(() => _pageId = id);
    ref.invalidate(sketchPagesProvider(widget.moduleId));
  }

  /// Mirrors mod/sketcher.js: a sample closer than 1.2 in Manhattan distance
  /// to the previous one is dropped, which keeps a stroke from storing a
  /// point per frame.
  void _addSample(Offset p) {
    if (_current.length >= 2) {
      final lx = _current[_current.length - 2];
      final ly = _current[_current.length - 1];
      if ((p.dx - lx).abs() + (p.dy - ly).abs() < 1.2) return;
    }
    setState(() => _current.addAll([p.dx, p.dy]));
  }

  Future<void> _commitStroke() async {
    if (_current.length < 2) {
      setState(() => _current = []);
      return;
    }
    final dao = ref.read(sketcherDaoProvider).valueOrNull;
    final page = _pageId;
    final pts = _current;
    setState(() => _current = []);
    if (dao == null || page == null) return;
    await dao.addStroke(pageRef: page, color: _color, width: _width, points: pts);
    ref.invalidate(sketchStrokesProvider(page));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pagesAsync = ref.watch(sketchPagesProvider(widget.moduleId));

    return pagesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (pages) {
        final page = pages.where((p) => p.id == _pageId).firstOrNull ??
            (pages.isEmpty ? null : pages.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(l10n.sketcherPages, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addPage,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.sketcherNewPage),
                  ),
                ],
              ),
            ),
            if (pages.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.sketcherNoPages, style: theme.textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) => ChoiceChip(
                    label: Text(pages[i].name, overflow: TextOverflow.ellipsis),
                    selected: page?.id == pages[i].id,
                    onSelected: (_) => setState(() {
                      _pageId = pages[i].id;
                      _current = [];
                    }),
                  ),
                ),
              ),
              if (page != null) ..._pageBody(context, l10n, theme, page),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _pageBody(
      BuildContext context, AppLocalizations l10n, ThemeData theme, SketchPageModel page) {
    final strokesAsync = ref.watch(sketchStrokesProvider(page.id));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text(_drawMode ? l10n.sketcherDraw : l10n.sketcherPan),
              selected: _drawMode,
              onSelected: (_) => setState(() => _drawMode = !_drawMode),
            ),
            for (final c in kSketchColors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parseHex(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == c ? theme.colorScheme.primary : theme.dividerColor,
                      width: _color == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
            for (final w in kSketchWidths)
              ChoiceChip(
                label: Text('${w.toInt()}'),
                selected: _width == w,
                onSelected: (_) => setState(() => _width = w),
              ),
            IconButton(
              tooltip: l10n.sketcherUndo,
              icon: const Icon(Icons.undo, size: 20),
              onPressed: () async {
                final dao = ref.read(sketcherDaoProvider).valueOrNull;
                if (dao == null) return;
                final last = await dao.lastStrokeId(page.id);
                if (last == null) return;
                await dao.deleteStroke(last);
                ref.invalidate(sketchStrokesProvider(page.id));
              },
            ),
            IconButton(
              tooltip: l10n.sketcherClear,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: l10n.confirmDeleteTitle,
                  message: l10n.sketcherClearWarning,
                );
                if (!ok) return;
                final dao = ref.read(sketcherDaoProvider).valueOrNull;
                await dao?.clearPage(page.id);
                ref.invalidate(sketchStrokesProvider(page.id));
              },
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: widget.boardHeight,
          child: ClipRect(
            child: InteractiveViewer(
              constrained: false,
              // Drawing and panning are the same gesture on a touch screen;
              // the toggle decides which one wins instead of both fighting.
              panEnabled: !_drawMode,
              scaleEnabled: !_drawMode,
              minScale: 0.2,
              maxScale: 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _drawMode ? (d) => _addSample(d.localPosition) : null,
                onPanUpdate: _drawMode ? (d) => _addSample(d.localPosition) : null,
                onPanEnd: _drawMode ? (_) => _commitStroke() : null,
                child: Container(
                  width: kSketchWidth,
                  height: kSketchHeight,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: strokesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(
                      child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                    data: (strokes) => CustomPaint(
                      size: const Size(kSketchWidth, kSketchHeight),
                      painter: _StrokePainter(
                        strokes: strokes,
                        current: _current,
                        currentColor: _parseHex(_color),
                        currentWidth: _width,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// The desktop stores colours as CSS hex strings. Anything unparseable falls
/// back to the first palette entry rather than throwing mid-paint.
Color _parseHex(String? hex) {
  final h = (hex ?? '').replaceFirst('#', '');
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return const Color(0xFFE879F9);
}

class _StrokePainter extends CustomPainter {
  final List<SketchStrokeModel> strokes;
  final List<double> current;
  final Color currentColor;
  final double currentWidth;

  const _StrokePainter({
    required this.strokes,
    required this.current,
    required this.currentColor,
    required this.currentWidth,
  });

  void _drawFlat(Canvas canvas, List<double> pts, Paint paint) {
    // Fewer than two points is not a line; the desktop skips these too.
    if (pts.length < 4) return;
    final path = Path()..moveTo(pts[0], pts[1]);
    for (var i = 2; i + 1 < pts.length; i += 2) {
      path.lineTo(pts[i], pts[i + 1]);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _drawFlat(
        canvas,
        s.points,
        Paint()
          ..color = _parseHex(s.color)
          ..strokeWidth = s.width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // The in-progress stroke is painted from local state so the line follows
    // the finger without a write per frame.
    _drawFlat(
      canvas,
      current,
      Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.strokes != strokes ||
      old.current.length != current.length ||
      old.currentColor != currentColor ||
      old.currentWidth != currentWidth;
}

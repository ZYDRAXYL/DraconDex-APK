import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/locator_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Locator kind: a map with drawable polygon areas.
///
/// The desktop draws this on a Konva stage whose coordinates are free world
/// space, so there is no canvas size to inherit the way Sketcher inherits
/// 1600x1100. Two consequences shape this editor:
///
///   Stored coordinates are used verbatim. Nothing here rescales a point to
///   fit the phone, because that would move every area the next time the map
///   opened on desktop.
///
///   The visible board is therefore derived, not fixed: it is sized to cover
///   both a default extent and every existing vertex, so a map drawn on
///   desktop at any coordinate range still shows up rather than falling
///   outside the widget and being clipped away.
class LocatorContent extends ConsumerWidget {
  final int moduleId;
  /// The board's height: 360 on a page, the screen's in full screen.
  final double boardHeight;

  const LocatorContent({super.key, required this.moduleId, this.boardHeight = 360});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mapAsync = ref.watch(moduleMapProvider(moduleId));

    return mapAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (map) => map == null
          ? const SizedBox.shrink()
          : _MapBoard(moduleId: moduleId, mapId: map.id, boardHeight: boardHeight),
    );
  }
}

class _MapBoard extends ConsumerStatefulWidget {
  final int moduleId;
  final int mapId;
  final double boardHeight;
  const _MapBoard({required this.moduleId, required this.mapId, required this.boardHeight});

  @override
  ConsumerState<_MapBoard> createState() => _MapBoardState();
}

class _MapBoardState extends ConsumerState<_MapBoard> {
  /// Default extent used when a map has no points yet, and the minimum the
  /// derived board will ever be.
  static const double _defaultW = 1600;
  static const double _defaultH = 1100;
  static const double _pad = 120;

  int? _areaId;
  bool _drawMode = false;

  Future<void> _addArea() async {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.read(locatorDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createArea(mapId: widget.mapId, name: l10n.locatorNewArea);
    if (!mounted) return;
    // A new area starts in draw mode: it has no vertices yet, and the only
    // useful next action is placing them.
    setState(() {
      _areaId = id;
      _drawMode = true;
    });
    ref.invalidate(mapAreasProvider(widget.mapId));
  }

  Future<void> _renameArea(MapAreaModel a) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: a.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.btnRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.labelName),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.btnSave),
          ),
        ],
      ),
    );
    if (name == null) return;
    final dao = ref.read(locatorDaoProvider).valueOrNull;
    await dao?.renameArea(a.id, name.isEmpty ? null : name);
    ref.invalidate(mapAreasProvider(widget.mapId));
  }

  Future<void> _deleteArea(MapAreaModel a) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.locatorDeleteAreaWarning,
    );
    if (!ok) return;
    final dao = ref.read(locatorDaoProvider).valueOrNull;
    await dao?.deleteArea(a.id);
    if (!mounted) return;
    if (_areaId == a.id) setState(() => _areaId = null);
    ref.invalidate(mapAreasProvider(widget.mapId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final areasAsync = ref.watch(mapAreasProvider(widget.mapId));

    return areasAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (areas) {
        final selected = areas.where((a) => a.id == _areaId).firstOrNull;

        // Derive the board from the content so desktop-drawn coordinates are
        // always inside it.
        var minX = 0.0, minY = 0.0, maxX = _defaultW, maxY = _defaultH;
        for (final a in areas) {
          for (final p in a.points) {
            if (p.x < minX) minX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.x > maxX) maxX = p.x;
            if (p.y > maxY) maxY = p.y;
          }
        }
        final origin = Offset(minX - _pad, minY - _pad);
        final boardW = (maxX + _pad) - origin.dx;
        final boardH = (maxY + _pad) - origin.dy;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(l10n.locatorAreas, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addArea,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.locatorNewArea),
                  ),
                ],
              ),
            ),
            if (areas.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.locatorNoAreas, style: theme.textTheme.bodySmall),
              )
            else
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: areas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) => ChoiceChip(
                    label: Text(
                      areas[i].name?.isNotEmpty == true
                          ? areas[i].name!
                          : l10n.locatorUntitledArea,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: _areaId == areas[i].id,
                    onSelected: (_) => setState(() => _areaId = areas[i].id),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(_drawMode ? l10n.locatorToolDraw : l10n.locatorToolMove),
                    selected: _drawMode,
                    // Tracing needs an area to put the vertices on.
                    onSelected:
                        selected == null ? null : (_) => setState(() => _drawMode = !_drawMode),
                  ),
                  if (selected != null) ...[
                    IconButton(
                      tooltip: l10n.locatorUndoPoint,
                      icon: const Icon(Icons.undo, size: 20),
                      onPressed: () async {
                        final dao = ref.read(locatorDaoProvider).valueOrNull;
                        if (dao == null) return;
                        final last = await dao.lastPointId(selected.id);
                        if (last == null) return;
                        await dao.deletePoint(last);
                        ref.invalidate(mapAreasProvider(widget.mapId));
                      },
                    ),
                    IconButton(
                      tooltip: l10n.btnRename,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _renameArea(selected),
                    ),
                    IconButton(
                      tooltip: l10n.btnDelete,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteArea(selected),
                    ),
                  ],
                ],
              ),
            ),
            if (_drawMode && selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.locatorDrawHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: widget.boardHeight,
                child: ClipRect(
                  child: InteractiveViewer(
                    constrained: false,
                    // Tapping to place a vertex and dragging to pan are the
                    // same gesture; the tool decides which one wins.
                    panEnabled: !_drawMode,
                    scaleEnabled: !_drawMode,
                    minScale: 0.15,
                    maxScale: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (!_drawMode || selected == null)
                          ? null
                          : (d) async {
                              final dao = ref.read(locatorDaoProvider).valueOrNull;
                              if (dao == null) return;
                              // Local position is board space; shift by the
                              // derived origin to get the stored world value.
                              await dao.addPoint(
                                areaId: selected.id,
                                x: d.localPosition.dx + origin.dx,
                                y: d.localPosition.dy + origin.dy,
                              );
                              ref.invalidate(mapAreasProvider(widget.mapId));
                            },
                      child: Container(
                        width: boardW,
                        height: boardH,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: CustomPaint(
                          size: Size(boardW, boardH),
                          painter: _AreaPainter(
                            areas: areas,
                            origin: origin,
                            selectedId: _areaId,
                            lineColor: theme.colorScheme.outline,
                            selectedColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<MapAreaModel> areas;
  final Offset origin;
  final int? selectedId;
  final Color lineColor;
  final Color selectedColor;

  const _AreaPainter({
    required this.areas,
    required this.origin,
    required this.selectedId,
    required this.lineColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in areas) {
      if (a.points.isEmpty) continue;
      final isSelected = a.id == selectedId;
      final stroke = isSelected ? selectedColor : lineColor;
      final pts = a.points.map((p) => Offset(p.x, p.y) - origin).toList();

      if (a.isPolygon) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = stroke.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = stroke
            ..strokeWidth = isSelected ? 2.5 : 1.5
            ..style = PaintingStyle.stroke,
        );
      } else if (pts.length == 2) {
        // Two vertices are not yet a shape, but the segment between them is
        // worth showing while tracing.
        canvas.drawLine(
          pts[0],
          pts[1],
          Paint()
            ..color = stroke
            ..strokeWidth = 1.5,
        );
      }

      // Vertex dots, so a half-traced area is visible and editable.
      for (final p in pts) {
        canvas.drawCircle(p, isSelected ? 5 : 3, Paint()..color = stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.areas != areas ||
      old.origin != origin ||
      old.selectedId != selectedId ||
      old.lineColor != lineColor ||
      old.selectedColor != selectedColor;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/wanderer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Wanderer kind: timeline events pinned onto a map.
///
/// This is the last of the eleven, and the only one that joins two other
/// kinds' data — Locator's map space and Chronicler's timeline events. It
/// follows Locator's coordinate rule exactly: free world space, stored
/// verbatim, with the visible board derived from content so pins placed on
/// desktop are never clipped away or silently moved.
///
/// map_event.event_ref is ON DELETE SET NULL, so a pin whose event was
/// deleted stays on the map with its link cleared. That is a legitimate
/// state and is shown as such rather than treated as broken.
class WandererContent extends ConsumerStatefulWidget {
  final int moduleId;
  final int nexusId;

  const WandererContent({super.key, required this.moduleId, required this.nexusId});

  @override
  ConsumerState<WandererContent> createState() => _WandererContentState();
}

class _WandererContentState extends ConsumerState<WandererContent> {
  static const double _defaultW = 1600;
  static const double _defaultH = 1100;
  static const double _pad = 120;

  bool _placeMode = false;
  final Map<int, Offset> _dragging = {};

  Future<void> _editPin(MapEventModel pin) async {
    final l10n = AppLocalizations.of(context)!;
    final events = ref.read(linkableEventsProvider(widget.nexusId)).valueOrNull ??
        const <LinkableEvent>[];
    final controller = TextEditingController(text: pin.label ?? '');
    var eventRef = pin.eventRef;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.wandererPin),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.wandererLabel),
                ),
                const SizedBox(height: 12),
                Text(l10n.wandererLinkedEvent,
                    style: Theme.of(ctx).textTheme.labelMedium),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.wandererNoEvents,
                        style: Theme.of(ctx).textTheme.bodySmall),
                  )
                else
                  DropdownButton<int?>(
                    value: events.any((e) => e.id == eventRef) ? eventRef : null,
                    isExpanded: true,
                    hint: Text(l10n.wandererNoLink),
                    items: [
                      // Clearing the link has to be reachable, not only
                      // settable by deleting the event upstream.
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.wandererNoLink),
                      ),
                      for (final e in events)
                        DropdownMenuItem<int?>(
                          value: e.id,
                          child: Text(
                            e.name.isEmpty
                                ? '${l10n.chroniclerUntitledEvent} · ${e.moduleName}'
                                : '${e.name} · ${e.moduleName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => eventRef = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('delete'),
              child: Text(l10n.btnDelete),
            ),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.btnCancel)),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop('save'), child: Text(l10n.btnSave)),
          ],
        ),
      ),
    );
    if (action == null) return;
    final dao = ref.read(wandererDaoProvider).valueOrNull;
    if (dao == null) return;
    if (action == 'delete') {
      final ok = await showConfirmDialog(
        context,
        title: l10n.confirmDeleteTitle,
        message: l10n.confirmDeleteMessage,
      );
      if (!ok) return;
      await dao.deletePin(pin.id);
    } else {
      final text = controller.text.trim();
      await dao.updatePin(pin.id, label: text.isEmpty ? null : text, eventRef: eventRef);
    }
    ref.invalidate(mapPinsProvider(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pinsAsync = ref.watch(mapPinsProvider(widget.moduleId));
    // Warmed here so the edit sheet can read it synchronously.
    ref.watch(linkableEventsProvider(widget.nexusId));

    return pinsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (pins) {
        var minX = 0.0, minY = 0.0, maxX = _defaultW, maxY = _defaultH;
        for (final p in pins) {
          final at = _dragging[p.id] ?? Offset(p.x, p.y);
          if (at.dx < minX) minX = at.dx;
          if (at.dy < minY) minY = at.dy;
          if (at.dx > maxX) maxX = at.dx;
          if (at.dy > maxY) maxY = at.dy;
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
                  Text(l10n.wandererPins, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  ChoiceChip(
                    label: Text(_placeMode ? l10n.wandererPlacing : l10n.locatorToolMove),
                    selected: _placeMode,
                    onSelected: (_) => setState(() => _placeMode = !_placeMode),
                  ),
                ],
              ),
            ),
            if (_placeMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.wandererPlaceHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              )
            else if (pins.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(l10n.wandererNoPins, style: theme.textTheme.bodySmall),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 360,
                child: ClipRect(
                  child: InteractiveViewer(
                    constrained: false,
                    panEnabled: !_placeMode,
                    scaleEnabled: !_placeMode,
                    minScale: 0.15,
                    maxScale: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: !_placeMode
                          ? null
                          : (d) async {
                              final dao = ref.read(wandererDaoProvider).valueOrNull;
                              if (dao == null) return;
                              await dao.createPin(
                                moduleRef: widget.moduleId,
                                x: d.localPosition.dx + origin.dx,
                                y: d.localPosition.dy + origin.dy,
                              );
                              ref.invalidate(mapPinsProvider(widget.moduleId));
                            },
                      child: SizedBox(
                        width: boardW,
                        height: boardH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                  color: theme.colorScheme.surfaceContainerHighest),
                            ),
                            for (final p in pins)
                              _Pin(
                                key: ValueKey(p.id),
                                at: (_dragging[p.id] ?? Offset(p.x, p.y)) - origin,
                                label: p.displayName,
                                linked: p.eventRef != null,
                                onTap: () => _editPin(p),
                                onDragUpdate: (o) =>
                                    setState(() => _dragging[p.id] = o + origin),
                                onDragEnd: () async {
                                  final world = _dragging[p.id];
                                  if (world == null) return;
                                  final dao =
                                      ref.read(wandererDaoProvider).valueOrNull;
                                  await dao?.movePin(p.id, world.dx, world.dy);
                                  if (!mounted) return;
                                  setState(() => _dragging.remove(p.id));
                                  ref.invalidate(mapPinsProvider(widget.moduleId));
                                },
                              ),
                          ],
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

class _Pin extends StatelessWidget {
  final Offset at;
  final String? label;
  final bool linked;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  const _Pin({
    super.key,
    required this.at,
    required this.label,
    required this.linked,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // An unlinked pin is drawn differently rather than hidden: event_ref is
    // SET NULL when its event goes away, and the user needs to see that.
    final color = linked ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Positioned(
      left: at.dx - 12,
      top: at.dy - 24,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onDragUpdate(at + d.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(linked ? Icons.place : Icons.place_outlined, size: 24, color: color),
            if (label != null)
              Container(
                constraints: const BoxConstraints(maxWidth: 140),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

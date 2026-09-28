import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/module_model.dart';
import '../module_actions.dart';

/// Drag a module onto a folder — the Nest tree's drag on the desktop
/// (EXE hub/tree.js) and a Unity Project window's, for a mouse or a trackpad:
/// the PWA in a browser, a tablet with a pointer. On touch a long press
/// already opens the row's menu (APP docs/APK-V3.md §5), so touch moves go
/// through its "Move to…" instead of fighting it for the gesture.
const _pointerDevices = {PointerDeviceKind.mouse, PointerDeviceKind.trackpad};

class ModuleDragSource extends StatelessWidget {
  final ModuleModel module;
  final Widget child;
  const ModuleDragSource({super.key, required this.module, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PointerDraggable<ModuleModel>(
      data: module,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(module.kindInfo.icon, size: 18),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

/// A [Draggable] that only a mouse or a trackpad starts — the override
/// [LongPressDraggable] itself uses to pick its recognizer.
class _PointerDraggable<T extends Object> extends Draggable<T> {
  const _PointerDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) =>
      ImmediateMultiDragGestureRecognizer(supportedDevices: _pointerDevices, allowedButtonsFilter: allowedButtonsFilter)
        ..onStart = onStart;
}

/// A place a dragged module can land: a Collector ([folderId]), or the top
/// level of a Nexus ([folderId] null). Only a Collector holds anything
/// (V5.md §8.8), so only those are wrapped in one. A drop onto the folder
/// the module is already in, or onto the module itself, is not offered; a
/// drop into its own subtree is refused by the move and said so.
class FolderDropTarget extends ConsumerWidget {
  final int nexusId;
  final int? folderId;
  final String folderName;
  final Widget child;
  const FolderDropTarget({
    super.key,
    required this.nexusId,
    required this.folderId,
    required this.folderName,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<ModuleModel>(
      onWillAcceptWithDetails: (d) =>
          d.data.nexusRef == nexusId && d.data.id != folderId && d.data.parentId != folderId,
      onAcceptWithDetails: (d) => moveModulesInto(context, ref, [d.data], folderId, folderName),
      builder: (context, candidates, _) => candidates.isEmpty
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                border: Border.all(color: scheme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            ),
    );
  }
}

/// [child] as both: draggable, and — when it is a Collector — a drop target.
Widget draggableModule({required int nexusId, required ModuleModel module, required Widget child}) {
  final source = ModuleDragSource(module: module, child: child);
  if (module.kind != ModuleKind.collector) return source;
  return FolderDropTarget(nexusId: nexusId, folderId: module.id, folderName: module.name, child: source);
}

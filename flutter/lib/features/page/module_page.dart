import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import 'arrange_mode.dart';
import 'component_registry.dart';
import 'core_components.dart';
import 'page_providers.dart';

/// Below this width a `columns` block stacks its columns into one (APK-V3.md
/// §10.4, §13 item 8): one layout for every screen, flowing with the width,
/// so a page arranged on a desktop arrives whole on a phone.
const double kColumnsMinWidth = 600;

/// A page: the module's own (itemKey null) or an element's — a stack of
/// blocks rendered top to bottom, in the order the desktop (or arrange mode
/// here) put them. Sits inside the screen's own scroll view.
class ModulePage extends ConsumerWidget {
  final int moduleId;
  final String? itemKey;

  const ModulePage({super.key, required this.moduleId, this.itemKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = PageKey(moduleId, itemKey);
    final page = ref.watch(pageProvider(key)).valueOrNull;
    if (page == null) return const SizedBox(height: 48);
    if (ref.watch(arrangeModeProvider(key))) return ArrangeList(page: page, pageKey: key);
    final wide = ddxLayoutOf(context).hasRail;
    final top = page.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < top.length; i++)
          BlockView(page: page, block: top[i], itemKey: itemKey, wide: wide, isDuplicateOnce: _dupOnce(top, i)),
      ],
    );
  }

  /// A `once` component that already appeared higher up the page.
  static bool _dupOnce(List<PageBlock> blocks, int i) {
    final b = blocks[i];
    if (b.type != 'component') return false;
    final def = components[b.component];
    if (def == null || !def.once) return false;
    return blocks.take(i).any((x) => x.type == 'component' && x.component == b.component && x.sourceKey == b.sourceKey);
  }
}

/// One block.
class BlockView extends ConsumerWidget {
  final PageData page;
  final PageBlock block;
  final String? itemKey;
  final bool wide;
  final bool isDuplicateOnce;

  const BlockView({
    super.key,
    required this.page,
    required this.block,
    required this.itemKey,
    required this.wide,
    this.isDuplicateOnce = false,
  });

  PageKey get _key => PageKey(page.module.id, itemKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: child);

    Future<void> saveContent(String v) async {
      final dao = await ref.read(pageBlockDaoProvider.future);
      await dao.update(block.id, content: v, clear: {if (v.isEmpty) 'content'});
      ref.invalidate(pageProvider(_key));
    }

    switch (block.type) {
      case 'text':
        return pad(TextSourceEditor(
          text: block.content ?? '',
          nexusId: page.module.nexusRef,
          title: l10n.pbText,
          onSave: saveContent,
        ));
      case 'heading':
        return pad(InkWell(
          onTap: () async {
            final next = await editTextSheet(context,
                title: l10n.pbHeading, initial: block.content ?? '', nexusId: page.module.nexusRef, singleLine: true);
            if (next != null) await saveContent(next);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              (block.content ?? '').isEmpty ? l10n.pbHeading : block.content!,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ));
      case 'divider':
        return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider());
      case 'image':
        return pad(ImageBlock(block: block, nexusId: page.module.nexusRef));
      case 'columns':
        final cols = page.columnsOf(block);
        return LayoutBuilder(builder: (context, c) {
          final kids = [
            for (final col in cols)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final b in col) BlockView(page: page, block: b, itemKey: itemKey, wide: wide)],
              ),
          ];
          if (c.maxWidth < kColumnsMinWidth) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final k in kids) Expanded(child: k)]);
        });
      case 'component':
        return ComponentBlockView(page: page, block: block, itemKey: itemKey, wide: wide, isDuplicateOnce: isDuplicateOnce);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// A component block: resolves its source (a borrowed block's module), then
/// draws the component, in a canvas frame when it is one.
class ComponentBlockView extends ConsumerWidget {
  final PageData page;
  final PageBlock block;
  final String? itemKey;
  final bool wide;
  final bool isDuplicateOnce;

  const ComponentBlockView({
    super.key,
    required this.page,
    required this.block,
    required this.itemKey,
    required this.wide,
    this.isDuplicateOnce = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final def = components[block.component];
    Widget note(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
        );
    if (def == null) return note('${block.component ?? '?'} · ${l10n.pbNotOnMobile}');
    if (isDuplicateOnce) return note('${def.label(l10n)} · ${l10n.pbOnlyOnce}');

    ModuleModel? source = page.module;
    final src = block.sourceKey;
    if (src != null) {
      final m = RegExp(r'^module_(\d+)$').firstMatch(src);
      source = m == null ? null : ref.watch(moduleProvider(int.parse(m.group(1)!))).valueOrNull;
      if (m == null || (source == null && ref.watch(moduleProvider(int.parse(m.group(1)!))).hasValue)) {
        return note('${def.label(l10n)} · ${l10n.pbSourceGone}');
      }
      if (source == null) return const SizedBox(height: 48);
    } else if (block.component != null && src == null && def.kind != null && def.kind != page.module.kind) {
      // Another kind's view with no source: nothing to read.
      return note('${def.label(l10n)} · ${l10n.pbSourceGone}');
    }

    final ctx = ComponentCtx(page: page, block: block, source: source, itemKey: itemKey, wide: wide);
    Widget body = def.build(context, ctx);
    if (def.canvas) body = CanvasFrame(title: source.name, wide: wide, child: body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ctx.borrowed || block.component == 'core.related')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              ctx.borrowed ? '↪ ${source.name} · ${def.label(l10n)}' : def.label(l10n),
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        if (block.component!.startsWith('core.') || block.component == 'item.body')
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: body)
        else
          body,
      ],
    );
  }
}

/// A board/map/canvas on a page (APK-V3.md §4, §13 item 15). On a phone it
/// is a thumbnail — one finger always scrolls the page, never gets caught in
/// a map — and a tap opens it full screen. On a tablet it draws inline, with
/// a full-screen button, the desktop's rule (V5.md §12.3).
class CanvasFrame extends StatelessWidget {
  final String title;
  final bool wide;
  final Widget child;

  const CanvasFrame({super.key, required this.title, required this.wide, required this.child});

  static const double thumbHeight = 220;

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: SingleChildScrollView(child: child)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    if (wide) {
      return Stack(
        children: [
          child,
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.fullscreen),
              tooltip: l10n.pbFullScreen,
              onPressed: () => _open(context),
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: SizedBox(
            height: thumbHeight,
            child: Stack(
              children: [
                // The real widget, drawn and clipped, but untouchable: the
                // thumbnail is a picture of the canvas, not the canvas.
                Positioned.fill(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: IgnorePointer(child: child),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Chip(
                    avatar: const Icon(Icons.open_in_full, size: 16),
                    label: Text(l10n.pbOpenFullScreen),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An image block: `source_key = file_<id>`, `content` = caption. The file
/// itself is the Asset Nest's (step 7); until one is picked it shows its
/// caption with a picture icon.
class ImageBlock extends ConsumerWidget {
  final PageBlock block;
  final int nexusId;
  const ImageBlock({super.key, required this.block, required this.nexusId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final image = imageBlockBuilder?.call(context, ref, block);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        image ??
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined, size: 36),
            ),
        if ((block.content ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(block.content!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

/// Set by the Asset Nest: draws an image block's picture.
Widget? Function(BuildContext context, WidgetRef ref, PageBlock block)? imageBlockBuilder;

/// Whether this module shows its children list under its page: a Collector
/// IS its children; every other kind is its page.
bool showsChildren(ModuleModel? m) => m == null || m.kind == ModuleKind.collector;

/// Forces a page to reload — after anything outside the page changed it.
void invalidatePage(WidgetRef ref, PageKey key) => ref.invalidate(pageProvider(key));

/// Reads `module_ui` for one key; used by components that remember a view.
Future<String?> moduleUi(WidgetRef ref, int moduleId, String key) async {
  final db = await ref.read(databaseProvider.future);
  final r = await db.rawQuery('SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key=?', [moduleId, key]);
  return r.isEmpty ? null : r.first['ui_value'] as String?;
}

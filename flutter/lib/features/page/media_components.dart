import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/services/assets/asset_open.dart';
import '../../data/services/assets/asset_store.dart';
import '../../data/services/export/doc_source.dart' show sniffImage;
import '../tools/assets_screen.dart';
import 'component_registry.dart';
import 'page_providers.dart';

/// The media blocks on the phone (Procress 14, APP docs/MEDIA-EMBED.md): the
/// desktop's `core.video`, `core.audio`, `core.pdf`, `core.model3d` and
/// `core.media`, reading the same `config.opts` — `file`, `files`, `poster`,
/// `cover`, `title`, `caption` as `file_<id>` references.
///
/// The phone ships no player, PDF reader or 3D viewer: each block is a
/// poster — the file's kept first frame / first page / model shot (the
/// proxy the desktop saves), or its class icon — and a tap hands the file to
/// the app on this device that opens it (asset_open.dart).
final List<ComponentDef> mediaComponents = [
  ComponentDef(id: 'core.video', kind: null, label: (l) => l.pcVideo, build: (c, x) => MediaBlock(ctx: x, kind: MediaKind.video)),
  ComponentDef(id: 'core.audio', kind: null, label: (l) => l.pcAudio, build: (c, x) => MediaBlock(ctx: x, kind: MediaKind.audio)),
  ComponentDef(id: 'core.pdf', kind: null, label: (l) => l.pcPdf, build: (c, x) => MediaBlock(ctx: x, kind: MediaKind.pdf)),
  ComponentDef(id: 'core.model3d', kind: null, label: (l) => l.pcModel3d, build: (c, x) => MediaBlock(ctx: x, kind: MediaKind.model)),
  ComponentDef(id: 'core.media', kind: null, label: (l) => l.pcMedia, build: (c, x) => MediaBlock(ctx: x, kind: MediaKind.mixed)),
];

/// Each media block and what it holds — also the add-block sheet's list.
const mediaBlockKinds = {
  'core.video': MediaKind.video,
  'core.audio': MediaKind.audio,
  'core.pdf': MediaKind.pdf,
  'core.model3d': MediaKind.model,
  'core.media': MediaKind.mixed,
};

enum MediaKind {
  video({'video'}, Icons.movie_outlined, false),
  audio({'audio'}, Icons.audiotrack_outlined, true),
  pdf({'pdf'}, Icons.picture_as_pdf_outlined, false),
  model({'model'}, Icons.view_in_ar_outlined, false),
  mixed({'image', 'video', 'model'}, Icons.perm_media_outlined, true);

  const MediaKind(this.classes, this.icon, this.many);

  /// What the picker offers — the desktop's `cls` for this block.
  final Set<String> classes;
  final IconData icon;

  /// A list of files (`opts.files`) rather than one (`opts.file`).
  final bool many;
}

int? fileIdOf(Object? ref) {
  final m = RegExp(r'^file_(\d+)$').firstMatch('${ref ?? ''}');
  return m == null ? null : int.parse(m[1]!);
}

Map<String, Object?> blockOpts(ComponentCtx ctx) {
  final o = ctx.block.config['opts'];
  return o is Map ? o.cast<String, Object?>() : const {};
}

/// The block's files, in order: `opts.files`, or the one `opts.file`.
List<int> mediaFileIds(Map<String, Object?> opts, bool many) {
  if (!many) {
    final id = fileIdOf(opts['file']);
    return id == null ? const [] : [id];
  }
  final list = opts['files'];
  return [for (final r in list is List ? list : const []) ?fileIdOf(r)];
}

/// Writes one option into `config.opts`, as the desktop's ⚙ does.
Future<void> setBlockOpt(WidgetRef ref, ComponentCtx ctx, String key, Object? value) async {
  final dao = await ref.read(pageBlockDaoProvider.future);
  final opts = {...blockOpts(ctx)};
  if (value == null) {
    opts.remove(key);
  } else {
    opts[key] = value;
  }
  await dao.update(ctx.block.id, config: {...ctx.block.config, 'opts': opts});
  ref.invalidate(pageProvider(ctx.key));
}

/// A picture to draw for an asset: its proxy, when the proxy is a picture
/// (on the web a non-image's "proxy" is the file itself).
Uint8List? posterBytes(Asset? a) {
  final p = a?.proxy;
  return p != null && sniffImage(p) != null && sniffImage(p) != 'svg' ? p : null;
}

class MediaBlock extends ConsumerWidget {
  final ComponentCtx ctx;
  final MediaKind kind;
  const MediaBlock({super.key, required this.ctx, required this.kind});

  Future<void> _add(BuildContext context, WidgetRef ref, List<int> ids) async {
    final id = await pickAsset(context, ref, ctx.nexusId, classes: kind.classes);
    if (id == null) return;
    if (kind.many) {
      await setBlockOpt(ref, ctx, 'files', [for (final i in {...ids, id}) 'file_$i']);
    } else {
      await setBlockOpt(ref, ctx, 'file', 'file_$id');
    }
  }

  Future<void> _open(BuildContext context, Asset a) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (a.isImage) {
      final bytes = await AssetStore.bytesOf(a);
      if (bytes == null || !context.mounted) return;
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(a.name)),
          body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
        ),
      ));
      return;
    }
    if (!await openAssetExternally(a)) messenger.showSnackBar(SnackBar(content: Text(l10n.mediaOpenFailed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final opts = blockOpts(ctx);
    final ids = mediaFileIds(opts, kind.many);
    final arranging = ref.watch(arrangeModeProvider(ctx.key));
    final all = ref.watch(assetsProvider(ctx.nexusId)).valueOrNull;
    if (all == null) return const SizedBox(height: 80);
    final byId = {for (final a in all) a.id: a};
    final files = [for (final id in ids) if (byId[id] case final a? when a.isOf(kind.classes)) a];

    if (files.isEmpty) {
      return _Empty(icon: kind.icon, text: l10n.pcMediaEmpty, action: l10n.pbChooseFile, onTap: () => _add(context, ref, ids));
    }
    final caption = '${opts['caption'] ?? ''}'.trim();
    final title = '${opts['title'] ?? ''}'.trim();
    final change = arranging
        ? Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _add(context, ref, ids),
              icon: Icon(kind.many ? Icons.add : Icons.swap_horiz, size: 18),
              label: Text(kind.many ? l10n.pcAddFile : l10n.pbChooseFile),
            ),
          )
        : null;

    switch (kind) {
      case MediaKind.audio:
        final cover = posterBytes(byId[fileIdOf(opts['cover'])]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 72,
                child: cover != null
                    ? Image.memory(cover, fit: BoxFit.cover)
                    : ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 32)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (title.isNotEmpty) Text(title, style: Theme.of(context).textTheme.titleSmall),
                for (final a in files)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Tooltip(message: l10n.pcOpenIn, child: const Icon(Icons.open_in_new, size: 18)),
                    onTap: () => _open(context, a),
                  ),
              ]),
            ),
          ]),
          ?change,
        ]);
      case MediaKind.mixed:
        final cols = int.tryParse('${opts['cols'] ?? ''}') ?? 3;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, box) {
            final n = box.maxWidth < 360 ? cols.clamp(2, 3) : cols.clamp(2, 5);
            final w = (box.maxWidth - 6 * (n - 1)) / n;
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in files)
                SizedBox(
                  width: w,
                  height: w,
                  child: _Poster(asset: a, poster: a.isImage ? a.proxy : posterBytes(a), compact: true, onTap: () => _open(context, a)),
                ),
            ]);
          }),
          ?change,
        ]);
      default:
        final a = files.first;
        final poster = posterBytes(kind == MediaKind.video ? (byId[fileIdOf(opts['poster'])] ?? a) : a) ?? posterBytes(a);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: kind == MediaKind.pdf ? 4 / 3 : 16 / 9,
            child: _Poster(asset: a, poster: poster, onTap: () => _open(context, a)),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(caption, style: TextStyle(fontSize: 13, color: context.ddx.textMuted)),
            ),
          ?change,
        ]);
    }
  }
}

/// A picture of the file with its kind on it; the whole tile opens it.
class _Poster extends StatelessWidget {
  final Asset asset;
  final Uint8List? poster;
  final bool compact;
  final VoidCallback onTap;
  const _Poster({required this.asset, required this.poster, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final badge = switch (asset.cls) {
      'video' => Icons.play_arrow_rounded,
      'model' => Icons.view_in_ar,
      'doc' => Icons.picture_as_pdf,
      _ => null,
    };
    return Semantics(
      button: true,
      label: '${asset.name}. ${asset.isImage ? '' : l10n.pcOpenIn}',
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            if (poster != null)
              Image.memory(poster!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Center(child: Icon(assetIcon(asset), size: compact ? 28 : 48, color: scheme.onSurfaceVariant)),
            // on a picture only: with no poster the class icon already says it
            if (badge != null && poster != null)
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                  child: Padding(padding: EdgeInsets.all(compact ? 6 : 10), child: Icon(badge, color: Colors.white, size: compact ? 20 : 32)),
                ),
              ),
            if (!compact)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB3000000)]),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    if (!asset.isImage) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text, action;
  final VoidCallback onTap;
  const _Empty({required this.icon, required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = context.ddx.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Icon(icon, size: 32, color: muted),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: muted)),
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.add, size: 18), label: Text(action)),
      ]),
    );
  }
}

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/links/safe_launch.dart';
import '../../core/theme/tokens.g.dart';
import '../../data/services/assets/asset_open.dart';
import '../../data/services/assets/asset_store.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/ddx_list.dart';
import '../../widgets/row_menu.dart';
import '../page/views/view_common.dart';
import 'folder_assets.dart';
import '../../widgets/sized_image.dart';
import '../../widgets/ddx_glass.dart';

final assetsProvider = FutureProvider.autoDispose.family<List<Asset>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  return AssetStore.list(db, nexusId);
});

final assetProvider = FutureProvider.autoDispose.family<Asset?, int>((ref, id) async {
  final db = await ref.watch(databaseProvider.future);
  return AssetStore.get(db, id);
});

final assetBytesProvider = FutureProvider.autoDispose.family<Uint8List?, int>((ref, id) async {
  final a = await ref.watch(assetProvider(id).future);
  return a == null ? null : AssetStore.bytesOf(a);
});

IconData assetIcon(Asset a) => switch (a.cls) {
      'image' => Icons.image_outlined,
      'audio' => Icons.audiotrack_outlined,
      'video' => Icons.movie_outlined,
      'doc' => a.type == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
      'track' => Icons.subtitles_outlined,
      'model' => Icons.view_in_ar_outlined,
      'url' => Icons.link,
      _ => Icons.insert_drive_file_outlined,
    };

String fileSize(int b) => b < 1024
    ? '$b B'
    : b < 1024 * 1024
        ? '${(b / 1024).toStringAsFixed(0)} KB'
        : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

/// A small square: the image's proxy, or its type's icon. One size in every
/// list (UX-LAYOUT §12 part 3) — a control's height, so it sits inside a
/// comfortable row.
class AssetThumb extends StatelessWidget {
  final Asset asset;
  final double size;
  const AssetThumb({super.key, required this.asset, this.size = DdxSize.ctlMd});

  @override
  Widget build(BuildContext context) {
    final p = asset.proxy;
    return SizedBox(
      width: size,
      height: size,
      child: asset.isImage && p != null
          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedImage(p, fit: BoxFit.cover, width: size, height: size, gaplessPlayback: true))
          : Icon(assetIcon(asset), size: size * 0.6),
    );
  }
}

/// Picks files from the device into the Nest; returns the new ids.
/// [classes] limits the picker to those asset classes (a video block asks
/// for 'video', a PDF block for 'pdf'). [folderId] files them in that
/// folder (a Collector) instead of the unfiled tray.
Future<List<int>> addAssetsFromDevice(BuildContext context, WidgetRef ref, int nexusId,
    {bool imagesOnly = false, Set<String>? classes, int? folderId}) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: !imagesOnly && classes == null,
    withData: true,
    type: imagesOnly ? FileType.image : (classes != null ? FileType.custom : FileType.any),
    allowedExtensions: !imagesOnly && classes != null ? extensionsOf(classes) : null,
  );
  if (res == null) return const [];
  final db = await ref.read(databaseProvider.future);
  final ids = <int>[];
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null) continue;
    final id = await AssetStore.addFile(db, nexusId, f.name, bytes, moduleRef: folderId);
    if (id == null) {
      messenger.showSnackBar(SnackBar(content: Text('${l.assetsTooBig}: ${f.name}')));
    } else {
      ids.add(id);
    }
  }
  ref.invalidate(assetsProvider(nexusId));
  ref.invalidate(nexusIndexProvider(nexusId));
  if (folderId != null) ref.invalidate(moduleAssetsProvider(folderId));
  return ids;
}

/// An asset of this Nexus, or a new one from the device — only [classes]
/// when given.
Future<int?> pickAsset(BuildContext context, WidgetRef ref, int nexusId, {bool imagesOnly = false, Set<String>? classes}) async {
  final l = AppLocalizations.of(context)!;
  final list = [
    for (final a in await ref.read(assetsProvider(nexusId).future))
      if ((!imagesOnly || a.isImage) && (classes == null || a.isOf(classes))) a,
  ];
  if (!context.mounted) return null;
  final pick = await showDdxSheet<int>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => SizedBox(
      height: MediaQuery.of(s).size.height * 0.6,
      child: ListView.builder(
        itemCount: list.length + 1,
        itemBuilder: (s, i) => i == 0
            ? DdxListTile(icon: Icons.add_photo_alternate_outlined, title: l.assetsFromDevice, onTap: () => Navigator.pop(s, -1))
            : DdxListTile(leading: AssetThumb(asset: list[i - 1]), title: list[i - 1].name, onTap: () => Navigator.pop(s, list[i - 1].id)),
      ),
    ),
  );
  if (pick == -1 && context.mounted) {
    final ids = await addAssetsFromDevice(context, ref, nexusId, imagesOnly: imagesOnly, classes: classes);
    return ids.isEmpty ? null : ids.first;
  }
  return pick;
}

/// The file-kind groups of the Asset Nest, in the order they show.
const _assetGroups = ['image', 'audio', 'video', 'doc', 'track', 'model', 'url', ''];

String _assetGroupLabel(AppLocalizations l, String cls) => switch (cls) {
      'image' => l.assetGroupImage,
      'audio' => l.assetGroupAudio,
      'video' => l.assetGroupVideo,
      'doc' => l.assetGroupDoc,
      'track' => l.assetGroupTrack,
      'model' => l.assetGroupModel,
      'url' => l.assetGroupUrl,
      _ => l.assetGroupOther,
    };

/// One file's row meta: the link, or its type and size.
String assetMeta(Asset a) => a.isUrl ? a.path : '${a.type.toUpperCase()} · ${fileSize(a.size)}';

/// The Asset Nest (V5.md §2, APK-V3.md §7): the Nexus's files and links,
/// grouped by kind of file (UX-LAYOUT §12 part 3).
class AssetsScreen extends ConsumerStatefulWidget {
  final int nexusId;
  const AssetsScreen({super.key, required this.nexusId});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String _filter = '';

  /// Newest first — the order the Nest has always listed them in.
  DdxSort _sort = DdxSort.created;

  int get nexusId => widget.nexusId;

  Future<void> _open(BuildContext context, Asset a) async {
    if (a.isUrl) {
      await safeLaunch(a.path);
      return;
    }
    if (a.isImage) {
      final bytes = await AssetStore.bytesOf(a);
      if (bytes == null || !context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (c) => Scaffold(
          appBar: DdxGlassBar(child: AppBar(title: Text(a.name))),
          body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
        ),
      ));
      return;
    }
    // a video, a PDF, a model: the app on this device that opens it
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context)!;
    if (!await openAssetExternally(a)) messenger.showSnackBar(SnackBar(content: Text(l.mediaOpenFailed)));
  }

  Future<void> _refresh() async {
    ref.invalidate(assetsProvider(nexusId));
    ref.invalidate(nexusIndexProvider(nexusId));
  }

  List<RowAction> _actions(BuildContext context, Asset a) {
    final l = AppLocalizations.of(context)!;
    return [
      RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => _open(context, a)),
      RowAction(
        label: l.btnRename,
        icon: Icons.edit_outlined,
        onTap: () async {
          final n = await askText(context, l.btnRename, initial: a.name, label: l.labelName);
          if (n == null) return;
          final db = await ref.read(databaseProvider.future);
          await AssetStore.rename(db, a.id, n);
          await _refresh();
        },
      ),
      // File it into a folder (V5.md §2.3) — what a .dxpack then
      // carries to the desktop's Locate folder.
      RowAction(
        label: l.moveTo,
        icon: Icons.drive_file_move_outline,
        onTap: () => moveAssetWithPicker(context, ref, nexusId, a),
      ),
      RowAction(
        label: l.btnDelete,
        icon: Icons.delete_outline,
        danger: true,
        onTap: () async {
          if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
          final db = await ref.read(databaseProvider.future);
          await AssetStore.delete(db, a.id);
          await _refresh();
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final list = ref.watch(assetsProvider(nexusId));

    return Scaffold(
      appBar: DdxGlassBar(child: AppBar(title: Text(l.assetsTitle), actions: [
        IconButton(
          tooltip: l.assetsAddUrl,
          icon: const Icon(Icons.add_link),
          onPressed: () async {
            final url = await askText(context, l.assetsAddUrl, label: 'https://…');
            if (url == null || !RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return;
            final db = await ref.read(databaseProvider.future);
            await AssetStore.addUrl(db, nexusId, url, null);
            await _refresh();
          },
        ),
      ])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAssetsFromDevice(context, ref, nexusId),
        icon: const Icon(Icons.add),
        label: Text(l.assetsFromDevice),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (assets) {
          final notice = SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l.assetsNotice, style: theme.textTheme.bodySmall),
            ),
          );
          if (assets.isEmpty) {
            return CustomScrollView(slivers: [
              notice,
              SliverToBoxAdapter(
                child: DdxEmptyState(
                  icon: Icons.perm_media_outlined,
                  message: l.assetsNone,
                  actionLabel: l.assetsFromDevice,
                  onAction: () => addAssetsFromDevice(context, ref, nexusId),
                ),
              ),
            ]);
          }
          final shown = ddxSorted(
            [for (final a in assets) if (ddxMatches(_filter, [a.name, a.type, if (a.isUrl) a.path])) a],
            _sort,
            name: (a) => a.name,
            created: (a) => a.id.toString().padLeft(12, '0'),
          );
          final byKind = <String, List<Asset>>{for (final g in _assetGroups) g: []};
          for (final a in shown) {
            byKind[_assetGroups.contains(a.cls) ? a.cls! : '']!.add(a);
          }
          // the notice, the header, then a group per kind of file, its rows
          // built as they scroll in: a Nest of thousands decodes only the
          // thumbs on screen
          return CustomScrollView(slivers: [
            notice,
            SliverToBoxAdapter(
              child: DdxListHeader(
                count: shown.length,
                onFilterChanged: (v) => setState(() => _filter = v),
                sort: _sort,
                sorts: const [DdxSort.name, DdxSort.created],
                onSortChanged: (s) => setState(() => _sort = s ?? DdxSort.created),
              ),
            ),
            if (shown.isEmpty)
              SliverToBoxAdapter(child: DdxEmptyState(icon: Icons.filter_list_off, message: l.listNoMatch)),
            for (final e in byKind.entries)
              if (e.value.isNotEmpty)
                DdxListSection.sliver(
                  storageId: 'assets-${e.key}',
                  title: _assetGroupLabel(l, e.key),
                  count: e.value.length,
                  itemCount: e.value.length,
                  itemBuilder: (context, i) {
                    final a = e.value[i];
                    return DdxListTile(
                      leading: AssetThumb(asset: a),
                      title: a.name,
                      meta: assetMeta(a),
                      actions: () => _actions(context, a),
                      onTap: () => _open(context, a),
                    );
                  },
                ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
          ]);
        },
      ),
    );
  }
}

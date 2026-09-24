import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/assets/asset_store.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/row_menu.dart';
import '../page/views/view_common.dart';

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
      'doc' => Icons.description_outlined,
      'url' => Icons.link,
      _ => Icons.insert_drive_file_outlined,
    };

String fileSize(int b) => b < 1024
    ? '$b B'
    : b < 1024 * 1024
        ? '${(b / 1024).toStringAsFixed(0)} KB'
        : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

/// A small square: the image's proxy, or its type's icon.
class AssetThumb extends StatelessWidget {
  final Asset asset;
  final double size;
  const AssetThumb({super.key, required this.asset, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final p = asset.proxy;
    return SizedBox(
      width: size,
      height: size,
      child: asset.isImage && p != null
          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(p, fit: BoxFit.cover, gaplessPlayback: true))
          : Icon(assetIcon(asset), size: size * 0.6),
    );
  }
}

/// Picks files from the device into the Nest; returns the new ids.
Future<List<int>> addAssetsFromDevice(BuildContext context, WidgetRef ref, int nexusId, {bool imagesOnly = false}) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: !imagesOnly,
    withData: true,
    type: imagesOnly ? FileType.image : FileType.any,
  );
  if (res == null) return const [];
  final db = await ref.read(databaseProvider.future);
  final ids = <int>[];
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null) continue;
    final id = await AssetStore.addFile(db, nexusId, f.name, bytes);
    if (id == null) {
      messenger.showSnackBar(SnackBar(content: Text('${l.assetsTooBig}: ${f.name}')));
    } else {
      ids.add(id);
    }
  }
  ref.invalidate(assetsProvider(nexusId));
  ref.invalidate(nexusIndexProvider(nexusId));
  return ids;
}

/// An asset of this Nexus, or a new one from the device.
Future<int?> pickAsset(BuildContext context, WidgetRef ref, int nexusId, {bool imagesOnly = false}) async {
  final l = AppLocalizations.of(context)!;
  final list = [for (final a in await ref.read(assetsProvider(nexusId).future)) if (!imagesOnly || a.isImage) a];
  if (!context.mounted) return null;
  final pick = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => SizedBox(
      height: MediaQuery.of(s).size.height * 0.6,
      child: ListView(children: [
        ListTile(leading: const Icon(Icons.add_photo_alternate_outlined), title: Text(l.assetsFromDevice), onTap: () => Navigator.pop(s, -1)),
        for (final a in list)
          ListTile(leading: AssetThumb(asset: a, size: 40), title: Text(a.name), onTap: () => Navigator.pop(s, a.id)),
      ]),
    ),
  );
  if (pick == -1 && context.mounted) {
    final ids = await addAssetsFromDevice(context, ref, nexusId, imagesOnly: imagesOnly);
    return ids.isEmpty ? null : ids.first;
  }
  return pick;
}

/// The Asset Nest (V5.md §2, APK-V3.md §7): the Nexus's files and links.
class AssetsScreen extends ConsumerWidget {
  final int nexusId;
  const AssetsScreen({super.key, required this.nexusId});

  Future<void> _open(BuildContext context, Asset a) async {
    if (a.isUrl) {
      await launchUrl(Uri.parse(a.path), mode: LaunchMode.externalApplication);
      return;
    }
    final bytes = await AssetStore.bytesOf(a);
    if (bytes == null || !context.mounted) return;
    if (a.isImage) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(a.name)),
          body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
        ),
      ));
    } else {
      await Share.shareXFiles([XFile.fromData(bytes, name: a.name)]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final list = ref.watch(assetsProvider(nexusId));
    Future<void> refresh() async {
      ref.invalidate(assetsProvider(nexusId));
      ref.invalidate(nexusIndexProvider(nexusId));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.assetsTitle), actions: [
        IconButton(
          tooltip: l.assetsAddUrl,
          icon: const Icon(Icons.add_link),
          onPressed: () async {
            final url = await askText(context, l.assetsAddUrl, label: 'https://…');
            if (url == null || !RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return;
            final db = await ref.read(databaseProvider.future);
            await AssetStore.addUrl(db, nexusId, url, null);
            await refresh();
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAssetsFromDevice(context, ref, nexusId),
        icon: const Icon(Icons.add),
        label: Text(l.assetsFromDevice),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (assets) => ListView(padding: const EdgeInsets.only(bottom: 88), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.assetsNotice, style: theme.textTheme.bodySmall),
          ),
          if (assets.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.assetsNone))),
          for (final a in assets)
            ListTile(
              leading: AssetThumb(asset: a),
              title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(a.isUrl ? a.path : '${a.type.toUpperCase()} · ${fileSize(a.size)}', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _open(context, a),
              onLongPress: () => showRowMenu(context, title: a.name, [
                RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => _open(context, a)),
                RowAction(
                  label: l.btnRename,
                  icon: Icons.edit_outlined,
                  onTap: () async {
                    final n = await askText(context, l.btnRename, initial: a.name, label: l.labelName);
                    if (n == null) return;
                    final db = await ref.read(databaseProvider.future);
                    await AssetStore.rename(db, a.id, n);
                    await refresh();
                  },
                ),
                RowAction(
                  label: l.btnDelete,
                  icon: Icons.delete_outline,
                  danger: true,
                  onTap: () async {
                    if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
                    final db = await ref.read(databaseProvider.future);
                    await AssetStore.delete(db, a.id);
                    await refresh();
                  },
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

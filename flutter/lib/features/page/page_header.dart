import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../core/theme/tokens.g.dart';
import '../../data/models/module_model.dart';
import '../../data/services/assets/asset_files.dart';
import '../../data/services/assets/asset_store.dart';
import '../../providers/db_providers.dart';
import 'page_providers.dart';

/// A page's title layout (APP docs/REDESIGN.md C6) — the same module_ui row
/// the desktop writes (EXE hub/page-head.js): "pageHead" for a module page,
/// `pageHead:<itemKey>` for an element page, value {align, cover, icon}. No
/// row, or '' (what "back to default" stores on both apps), is left / no
/// cover / no icon. The cover names an Asset Nest image by sha256 — ids
/// differ per device, the hash does not.
class PageHeadLayout {
  const PageHeadLayout({this.align = 'left', this.cover, this.icon});

  final String align;
  final String? cover;
  final String? icon;

  static const aligns = ['left', 'center', 'right'];
  static const empty = PageHeadLayout();

  bool get isDefault => align == 'left' && cover == null && icon == null;

  /// Tolerant on purpose: the row is written by two apps and travels through
  /// sync, so anything malformed reads as the default rather than throwing.
  static PageHeadLayout parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    Object? v;
    try {
      v = jsonDecode(raw);
    } catch (_) {
      return empty;
    }
    if (v is! Map) return empty;
    final a = v['align'];
    final c = v['cover'];
    final i = v['icon'];
    final icon = i is String && i.trim().isNotEmpty ? i.trim().characters.take(4).toString() : null;
    return PageHeadLayout(
      align: aligns.contains(a) ? a as String : 'left',
      cover: c is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(c) ? c : null,
      icon: icon,
    );
  }

  /// What goes in module_ui.ui_value: '' for the default, as EXE stores it.
  String encode() => isDefault ? '' : jsonEncode({'align': align, 'cover': cover, 'icon': icon});

  PageHeadLayout copyWith({String? align, Object? cover = _keep, Object? icon = _keep}) => PageHeadLayout(
        align: align ?? this.align,
        cover: identical(cover, _keep) ? this.cover : cover as String?,
        icon: identical(icon, _keep) ? this.icon : icon as String?,
      );
}

const Object _keep = Object();

String pageHeadKey(String? itemKey) => itemKey == null ? 'pageHead' : 'pageHead:$itemKey';

final pageHeadProvider = FutureProvider.autoDispose.family<PageHeadLayout, PageKey>((ref, key) async {
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.rawQuery('SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key=?', [key.moduleId, pageHeadKey(key.itemKey)]);
  return PageHeadLayout.parse(rows.isEmpty ? null : rows.first['ui_value'] as String?);
});

Future<void> savePageHead(WidgetRef ref, PageKey key, PageHeadLayout next) async {
  final db = await ref.read(databaseProvider.future);
  await db.insert('module_ui', {'module_ref': key.moduleId, 'ui_key': pageHeadKey(key.itemKey), 'ui_value': next.encode()},
      conflictAlgorithm: ConflictAlgorithm.replace);
  ref.invalidate(pageHeadProvider(key));
}

/// An image of this Nexus the cover can use: its hash and something to draw.
class CoverImage {
  const CoverImage(this.sha, this.name, this.bytes);
  final String sha;
  final String name;
  final Uint8List bytes;
}

/// The Nexus's images, drawable here. The file when this device has it,
/// otherwise the proxy thumbnail the row carries — sync brings the row, not
/// the file — and an image with neither is left out.
final coverImagesProvider = FutureProvider.autoDispose.family<List<CoverImage>, int>((ref, nexusId) async {
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.rawQuery(
      "SELECT file_name, file_path, file_type, sha256, proxy FROM import_file "
      "WHERE nexus_ref=? AND sha256 IS NOT NULL AND COALESCE(source_kind,'file') != 'url' ORDER BY id DESC",
      [nexusId]);
  final out = <CoverImage>[];
  for (final r in rows) {
    if (assetClass[(r['file_type'] as String? ?? '').toLowerCase()] != 'image') continue;
    final bytes = await readAssetFile(r['file_path'] as String? ?? '') ?? r['proxy'] as Uint8List?;
    if (bytes == null || bytes.isEmpty) continue;
    out.add(CoverImage(r['sha256'] as String, r['file_name'] as String? ?? '', bytes));
  }
  return out;
});

/// The page's title, laid out the way the page says: aligned, with its
/// icon above and its cover over it. Applied as set on every screen size —
/// right is right on a phone too (C6). On iOS it is the page's large title.
class PageHeader extends ConsumerWidget {
  const PageHeader({super.key, required this.module, required this.itemKey, required this.title});

  final ModuleModel module;
  final String? itemKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lay = ref.watch(pageHeadProvider(PageKey(module.id, itemKey))).valueOrNull ?? PageHeadLayout.empty;
    final cover = lay.cover == null
        ? null
        : ref.watch(coverImagesProvider(module.nexusRef)).valueOrNull?.where((c) => c.sha == lay.cover).firstOrNull;
    final align = switch (lay.align) { 'center' => TextAlign.center, 'right' => TextAlign.right, _ => TextAlign.left };
    final cross = switch (lay.align) {
      'center' => CrossAxisAlignment.center,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final ios = context.isIosStyle;
    final style = ios
        ? const TextStyle(fontSize: DdxIos.sizeLargeTitle, fontWeight: FontWeight.w700, height: 1.2)
        : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          if (cover != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.ddx.radiusLarge),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.memory(cover.bytes, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
            ),
          if (lay.icon != null) Text(lay.icon!, style: const TextStyle(fontSize: 40, height: 1.1)),
          SizedBox(
            width: double.infinity,
            child: Text(title, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
          ),
        ],
      ),
    );
  }
}

/// "Title layout…" from the page's ⋮ — the sheet the desktop's popover is.
Future<void> showPageLayoutSheet(BuildContext context, WidgetRef ref, ModuleModel module, String? itemKey) async {
  final key = PageKey(module.id, itemKey);
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _PageLayoutSheet(pageKey: key, nexusId: module.nexusRef),
  );
}

class _PageLayoutSheet extends ConsumerStatefulWidget {
  const _PageLayoutSheet({required this.pageKey, required this.nexusId});

  final PageKey pageKey;
  final int nexusId;

  @override
  ConsumerState<_PageLayoutSheet> createState() => _PageLayoutSheetState();
}

class _PageLayoutSheetState extends ConsumerState<_PageLayoutSheet> {
  final _icon = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save(PageHeadLayout next) => savePageHead(ref, widget.pageKey, next);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lay = ref.watch(pageHeadProvider(widget.pageKey)).valueOrNull;
    if (lay == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    if (!_seeded) {
      _icon.text = lay.icon ?? '';
      _seeded = true;
    }
    final images = ref.watch(coverImagesProvider(widget.nexusId)).valueOrNull ?? const <CoverImage>[];
    final muted = context.ddx.textMuted;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: TextStyle(fontSize: 12, color: muted)),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pageLayout, style: Theme.of(context).textTheme.titleMedium),
            label(l10n.titleAlign),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'left', label: Text(l10n.alignLeft)),
                ButtonSegment(value: 'center', label: Text(l10n.alignCenter)),
                ButtonSegment(value: 'right', label: Text(l10n.alignRight)),
              ],
              selected: {lay.align},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _save(lay.copyWith(align: s.first)),
            ),
            label(l10n.pageIcon),
            TextField(
              controller: _icon,
              maxLength: 16,
              decoration: const InputDecoration(hintText: '✦', counterText: ''),
              onSubmitted: (v) => _save(lay.copyWith(icon: v.trim().isEmpty ? null : v.trim())),
              onTapOutside: (_) => _save(lay.copyWith(icon: _icon.text.trim().isEmpty ? null : _icon.text.trim())),
            ),
            label(l10n.pageCover),
            if (images.isEmpty)
              Text(l10n.pageCoverEmpty, style: TextStyle(fontSize: 12, color: muted))
            else
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CoverChoice(
                      selected: lay.cover == null,
                      tooltip: l10n.pageCoverNone,
                      onTap: () => _save(lay.copyWith(cover: null)),
                      child: const Icon(Icons.hide_image_outlined),
                    ),
                    for (final c in images)
                      _CoverChoice(
                        selected: lay.cover == c.sha,
                        tooltip: c.name,
                        onTap: () => _save(lay.copyWith(cover: c.sha)),
                        child: Image.memory(c.bytes, fit: BoxFit.cover, width: 96, height: 60, gaplessPlayback: true),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(l10n.pageLayoutScope, style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
    );
  }
}

class _CoverChoice extends StatelessWidget {
  const _CoverChoice({required this.selected, required this.tooltip, required this.onTap, required this.child});

  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 96,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.ddx.raised,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      );
}

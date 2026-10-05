import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../data/dao/module_dao.dart';
import '../../data/services/assets/asset_store.dart';
import '../../providers/db_providers.dart';
import '../../providers/navigation_providers.dart';
import '../hub/widgets/move_to_sheet.dart';
import 'assets_screen.dart';
import 'folder_assets.dart';

/// "Share → DraconDex" on Android (APP Procress 16 part 2): files another app
/// shares wait in MainActivity.kt until this takes them, asks which Nexus and
/// which folder, and files them into the Nest. Wraps the app; does nothing
/// anywhere but Android.
class ShareInbox extends ConsumerStatefulWidget {
  final Widget child;
  const ShareInbox({super.key, required this.child});

  static const channel = MethodChannel('dracondex/share');

  @override
  ConsumerState<ShareInbox> createState() => _ShareInboxState();
}

class _ShareInboxState extends ConsumerState<ShareInbox> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    ShareInbox.channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _take();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  Future<void> _take() async {
    final raw = await ShareInbox.channel.invokeListMethod<Map<Object?, Object?>>('take') ?? const [];
    final files = [
      for (final m in raw)
        if (m['bytes'] is Uint8List) (name: '${m['name'] ?? 'shared'}', bytes: m['bytes'] as Uint8List),
    ];
    if (files.isEmpty) return;
    final db = await ref.read(databaseProvider.future);
    final nexuses = await ModuleDao(db).getNexuses();
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
    if (nexuses.isEmpty || ctx == null || !ctx.mounted) return;
    final l = AppLocalizations.of(ctx)!;

    final nexusId = nexuses.length == 1
        ? nexuses.single.id
        : await showModalBottomSheet<int>(
            context: ctx,
            showDragHandle: true,
            builder: (s) => ListView(shrinkWrap: true, children: [
              ListTile(title: Text(l.transferNexusLabel, style: Theme.of(s).textTheme.titleMedium)),
              for (final n in nexuses) ListTile(leading: const Icon(Icons.workspaces_outlined), title: Text(n.name), onTap: () => Navigator.pop(s, n.id)),
            ]),
          );
    if (nexusId == null || !ctx.mounted) return;
    final target = await showMoveToSheet(ctx, nexusId: nexusId);
    if (target == null || !ctx.mounted) return;

    final messenger = ScaffoldMessenger.of(ctx);
    for (final f in files) {
      if (await AssetStore.addFile(db, nexusId, f.name, f.bytes, moduleRef: target.parentId) == null) {
        messenger.showSnackBar(SnackBar(content: Text('${l.assetsTooBig}: ${f.name}')));
      }
    }
    ref.invalidate(assetsProvider(nexusId));
    ref.invalidate(nexusIndexProvider(nexusId));
    if (target.parentId != null) ref.invalidate(moduleAssetsProvider(target.parentId!));
    messenger.showSnackBar(SnackBar(content: Text(l.moveDone.replaceAll('{name}', target.name))));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

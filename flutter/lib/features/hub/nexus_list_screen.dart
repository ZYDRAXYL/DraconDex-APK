import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/module_provider.dart';
import '../../providers/update_provider.dart';
import '../update/update_dialog.dart';
import 'dialogs/nexus_dialog.dart';
import 'widgets/nexus_collection_view.dart';

/// The Builder's home screen: a drill-down explorer, like a phone's
/// file-manager app. Each Nexus is a top-level "drive"; tapping one opens its
/// module tree. The Navibar under it comes from [BuilderShell].
class NexusListScreen extends ConsumerStatefulWidget {
  const NexusListScreen({super.key});

  @override
  ConsumerState<NexusListScreen> createState() => _NexusListScreenState();
}

class _NexusListScreenState extends ConsumerState<NexusListScreen> {
  bool _checkedForUpdate = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget, once per app open — never throws, so a failed or
    // offline check is silently a no-op (see UpdateService.checkForUpdate).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowUpdate());
  }

  Future<void> _maybeShowUpdate() async {
    if (_checkedForUpdate) return;
    _checkedForUpdate = true;
    final result = await ref.read(updateCheckProvider.future);
    if (!mounted || !result.available || result.dismissed || result.update == null) return;
    await showDialog(context: context, builder: (_) => UpdateDialog(update: result.update!));
  }

  @override
  Widget build(BuildContext context) {
    final nexusesAsync = ref.watch(nexusesProvider);
    final viewMode = ref.watch(builderViewModeProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // On a tablet these three live on the shell's rail, permanently, and
    // repeating them in the app bar would just be two ways to the same page.
    final onRail = ddxLayoutOf(context).hasRail;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          if (!onRail) ...[
            IconButton(
              icon: const Icon(Icons.palette),
              tooltip: l10n.moduleColors,
              onPressed: () => context.push('/colors'),
            ),
            IconButton(
              icon: const Icon(Icons.sell),
              tooltip: l10n.moduleGlobalTags,
              onPressed: () => context.push('/tags'),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.moduleSettings,
              onPressed: () => context.push('/settings'),
            ),
          ],
        ],
      ),
      body: nexusesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (nexuses) {
          if (nexuses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspaces_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(l10n.emptyNexusMessage, style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return NexusCollectionView(nexuses: nexuses, mode: viewMode);
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newNexusTooltip,
        onPressed: () async {
          await showDialog(context: context, builder: (_) => const NexusDialog());
          ref.invalidate(nexusesProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

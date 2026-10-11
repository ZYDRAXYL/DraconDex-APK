import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/module_provider.dart';
import '../../providers/update_provider.dart';
import '../../widgets/ddx_list.dart';
import '../../widgets/large_title_layout.dart';
import '../builder/view_mode_button.dart';
import '../update/update_dialog.dart';
import 'dialogs/nexus_dialog.dart';
import 'widgets/nexus_collection_view.dart';

/// The Builder's home screen: a drill-down explorer, like a phone's
/// file-manager app. Each Nexus is a top-level "drive"; tapping one opens its
/// module tree. The Navibar under it comes from [BuilderShell], which is
/// also where Colours, Labels and Settings went (APP docs/APK-V3.md §10.1) —
/// the app bar keeps the one choice that is about this page, its view mode.
class NexusListScreen extends ConsumerStatefulWidget {
  const NexusListScreen({super.key});

  @override
  ConsumerState<NexusListScreen> createState() => _NexusListScreenState();
}

class _NexusListScreenState extends ConsumerState<NexusListScreen> {
  bool _checkedForUpdate = false;
  String _filter = '';
  DdxSort _sort = DdxSort.name;

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

  Future<void> _newNexus() async {
    await showDialog(context: context, builder: (_) => const NexusDialog());
    ref.invalidate(nexusesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final nexusesAsync = ref.watch(nexusesProvider);
    final viewMode = ref.watch(builderViewModeProvider);
    final l10n = AppLocalizations.of(context)!;

    final list = nexusesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (nexuses) {
          if (nexuses.isEmpty) {
            return DdxEmptyState(
              icon: Icons.workspaces_outlined,
              message: l10n.emptyNexusMessage,
              actionLabel: l10n.newNexusTooltip,
              onAction: _newNexus,
            );
          }
          final shown = ddxSorted(
            [for (final n in nexuses) if (ddxMatches(_filter, [n.name, n.memo])) n],
            _sort,
            name: (n) => n.name,
            edited: (n) => n.updatedAt,
          );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DdxListHeader(
              count: shown.length,
              onFilterChanged: (v) => setState(() => _filter = v),
              sort: _sort,
              sorts: const [DdxSort.name, DdxSort.edited],
              onSortChanged: (s) => setState(() => _sort = s ?? DdxSort.name),
            ),
            Expanded(
              child: shown.isEmpty
                  ? DdxEmptyState(icon: Icons.filter_list_off, message: l10n.listNoMatch)
                  : NexusCollectionView(nexuses: shown, mode: viewMode),
            ),
          ]);
        },
      );

    return Scaffold(
      body: LargeTitleLayout(
        title: l10n.appName,
        appBar: (showTitle) => AppBar(
          title: showTitle ? Text(l10n.appName) : null,
          actions: const [ViewModeButton()],
        ),
        body: list,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newNexusTooltip,
        onPressed: _newNexus,
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/platform/saf.dart';
import '../../data/models/module_model.dart';
import '../../data/services/portlink/port_drive.dart';
import '../../data/services/portlink/portlink_merge.dart';
import '../../data/services/portlink/portlink_service.dart';
import '../../providers/portlink_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/ddx_glass.dart';
import '../../widgets/ddx_list.dart';
import '../../widgets/ddx_segmented.dart';
import '../../widgets/row_menu.dart';

/// Settings → Data → Portable drive (APP Plan.md Procress 32 part 9.6): the
/// folders of portable DraconDex copies this phone was given (USB-OTG, SD),
/// what each holds, and "clone to this phone". A Nexus already here is
/// cloned TO a drive from its own row menu ([portlinkActions]).
class PortDriveScreen extends ConsumerWidget {
  const PortDriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final drives = ref.watch(portDrivesProvider);
    final links = ref.watch(portLinksProvider).valueOrNull ?? const {};
    return Scaffold(
      appBar: DdxGlassBar(child: AppBar(title: Text(l10n.portDriveTitle))),
      body: ListView(children: [
        DdxListSection(title: l10n.portDriveTitle, collapsible: false, children: [
          DdxListTile(icon: Icons.create_new_folder_outlined, title: l10n.portDriveAdd, meta: l10n.portDriveAddHint, metaMaxLines: 2, onTap: () async {
            if (await Saf.pickTree() != null) ref.invalidate(portDrivesProvider);
          }),
        ]),
        ...?drives.valueOrNull?.map((d) => _drive(context, ref, l10n, d, links)),
        if (drives.isLoading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }

  Widget _drive(BuildContext context, WidgetRef ref, AppLocalizations l10n, PortDriveState d, Map<int, dynamic> links) {
    final info = d.info;
    final linkedHere = {for (final l in links.values) if (info != null && l.driveUid == info.driveUid) l.driveNexusId};
    final status = !d.available
        ? l10n.portDriveUnplugged
        : info == null
            ? l10n.portDriveNotFound
            : info.ownRoot.isEmpty
                ? l10n.portDriveNeverRan
                : info.nexuses.isEmpty
                    ? l10n.portDriveEmpty
                    : null;
    return DdxListSection(title: info?.ownRoot.isNotEmpty == true ? info!.ownRoot : l10n.portDriveTitle, collapsible: false, children: [
      if (status != null) DdxListTile(icon: Icons.usb_off, title: status),
      for (final n in info?.nexuses ?? const <DriveNexus>[])
        if (!n.missing)
          DdxListTile(
            icon: linkedHere.contains(n.id) ? Icons.link : Icons.workspaces_outlined,
            title: n.name,
            meta: linkedHere.contains(n.id) ? l10n.portLinked : n.memo,
            actions: linkedHere.contains(n.id)
                ? null
                : () => [RowAction(label: l10n.portCloneHere, icon: Icons.download, onTap: () => _cloneHere(context, ref, d.tree, n))],
            onTap: linkedHere.contains(n.id) ? null : () => _cloneHere(context, ref, d.tree, n),
          ),
      DdxListTile(
        icon: Icons.link_off,
        title: l10n.portDriveForget,
        onTap: () async {
          await Saf.release(d.tree);
          ref.invalidate(portDrivesProvider);
        },
      ),
    ]);
  }

  Future<void> _cloneHere(BuildContext context, WidgetRef ref, String tree, DriveNexus n) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final svc = await ref.read(portlinkServiceProvider.future);
    if (svc == null) return;
    final r = await svc.cloneFromDrive(SafDrive(tree), n.id);
    messenger.showSnackBar(SnackBar(content: Text(r.ok ? '${l10n.portSynced}: ${r.name}' : portMessage(l10n, r))));
    refreshAfterSync(ref);
    ref.invalidate(portDrivesProvider);
  }
}

/// The only place a Port Link outcome code becomes words.
String portMessage(AppLocalizations l10n, PortResult r) => switch (r.code) {
      null => r.unchanged ? l10n.portUnchanged : l10n.portSynced,
      'no_drive' || 'gone' => l10n.portErrNoDrive,
      'drive_changed' => l10n.portErrChanged,
      'map_broken' => l10n.portErrMapBroken,
      'never_ran' => l10n.portDriveNeverRan,
      'needs_choice' => l10n.portNeedsYou,
      _ => l10n.portErrFailed.replaceAll('{code}', r.code!),
    };

/// A Nexus row's Port Link entries: "clone to a drive" when it is not linked,
/// "sync now" / "stop syncing" when it is. None where there is no SAF.
List<RowAction> portlinkActions(BuildContext context, WidgetRef ref, NexusModel nexus) {
  if (!Saf.supported) return const [];
  final l10n = AppLocalizations.of(context)!;
  final link = ref.read(portLinksProvider).valueOrNull?[nexus.id];
  if (link == null) {
    return [RowAction(label: l10n.portCloneToDrive, icon: Icons.usb, group: RowGroup.share, onTap: () => _cloneToDrive(context, ref, nexus))];
  }
  return [
    RowAction(label: l10n.portSyncNow, icon: Icons.sync, group: RowGroup.share, quick: true, onTap: () => syncNow(context, ref, nexus.id)),
    RowAction(
      label: l10n.portUnlink,
      icon: Icons.link_off,
      group: RowGroup.share,
      onTap: () async {
        if (!await showConfirmDialog(context, title: l10n.portUnlink, message: l10n.portUnlinkMessage)) return;
        await (await ref.read(portlinkServiceProvider.future))?.unlink(nexus.id);
        ref.invalidate(portLinksProvider);
      },
    ),
  ];
}

Future<void> _cloneToDrive(BuildContext context, WidgetRef ref, NexusModel nexus) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final drives = [for (final d in await ref.read(portDrivesProvider.future)) if (d.info != null && d.info!.ownRoot.isNotEmpty) d];
  if (!context.mounted) return;
  if (drives.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.portErrNoDrive)));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortDriveScreen()));
    return;
  }
  final tree = drives.length == 1
      ? drives.single.tree
      : await showDdxSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: DdxListSection(title: l10n.portPickDrive, collapsible: false, children: [
              for (final d in drives) DdxListTile(icon: Icons.usb, title: d.info!.ownRoot, onTap: () => Navigator.of(ctx).pop(d.tree)),
            ]),
          ),
        );
  if (tree == null) return;
  final svc = await ref.read(portlinkServiceProvider.future);
  final r = await svc!.cloneToDrive(nexus.id, SafDrive(tree));
  messenger.showSnackBar(SnackBar(content: Text(portMessage(l10n, r))));
  ref.invalidate(portLinksProvider);
  ref.invalidate(portDrivesProvider);
}

/// Sync one Nexus now; when a cell changed on both sides, ask (bottom sheet)
/// and sync again with the answers.
Future<void> syncNow(BuildContext context, WidgetRef ref, int nexusId) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final svc = await ref.read(portlinkServiceProvider.future);
  final link = ref.read(portLinksProvider).valueOrNull?[nexusId];
  if (svc == null || link == null) return;
  final drive = SafDrive(link.treeUri);
  var r = await svc.sync(nexusId, drive);
  if (r.code == 'needs_choice' && context.mounted) {
    final choices = await showDdxSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PortConflictSheet(conflicts: r.conflicts),
    );
    if (choices == null) return;
    r = await svc.sync(nexusId, drive, choices: choices);
  }
  final state = Map<int, String>.of(ref.read(portSyncStateProvider));
  r.ok ? state.remove(nexusId) : state[nexusId] = r.code!;
  ref.read(portSyncStateProvider.notifier).state = state;
  messenger.showSnackBar(SnackBar(content: Text(portMessage(l10n, r))));
  if (r.ok && !r.unchanged) refreshAfterSync(ref);
}

/// "Changed on both sides": one row per cell — this phone's value or the
/// drive's — or all one way. Pops the answers, keyed as the merge asks.
class PortConflictSheet extends StatefulWidget {
  final List<PortlinkConflict> conflicts;
  const PortConflictSheet({super.key, required this.conflicts});

  @override
  State<PortConflictSheet> createState() => _PortConflictSheetState();
}

class _PortConflictSheetState extends State<PortConflictSheet> {
  late final Map<String, String> _pick = {for (final c in widget.conflicts) c.key: 'local'};

  String _show(Object? v) {
    final s = '${v ?? '—'}';
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void all(String side) => setState(() => _pick.updateAll((_, _) => side));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DdxListTile(title: l10n.portConflictTitle, meta: l10n.portConflictHint, metaMaxLines: 2),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in widget.conflicts) ...[
                DdxListTile(
                  title: '${c.label ?? c.table} · ${c.col}',
                  meta: '${l10n.portThisPhone}: ${_show(c.local)}\n${l10n.portTheDrive}: ${_show(c.drive)}',
                  metaMaxLines: 4,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: DdxSegmented<String>(
                    segments: [
                      DdxSegment(value: 'local', icon: Icons.phone_android, label: l10n.portThisPhone),
                      DdxSegment(value: 'drive', icon: Icons.usb, label: l10n.portTheDrive),
                    ],
                    selected: _pick[c.key]!,
                    onChanged: (v) => setState(() => _pick[c.key] = v),
                  ),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
              TextButton(onPressed: () => all('local'), child: Text(l10n.portAllPhone)),
              TextButton(onPressed: () => all('drive'), child: Text(l10n.portAllDrive)),
              FilledButton(onPressed: () => Navigator.of(context).pop(Map.of(_pick)), child: Text(l10n.portApply)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The mark after a linked Nexus's name: linked, or waiting on the user.
class PortLinkMark extends ConsumerWidget {
  final int nexusId;
  final double size;
  const PortLinkMark({super.key, required this.nexusId, this.size = 18});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Saf.supported) return const SizedBox.shrink();
    final linked = ref.watch(portLinksProvider).valueOrNull?.containsKey(nexusId) ?? false;
    if (!linked) return const SizedBox.shrink();
    final code = ref.watch(portSyncStateProvider)[nexusId];
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final needsYou = code == 'needs_choice' || code == 'map_broken';
    return Tooltip(
      message: needsYou ? l10n.portNeedsYou : l10n.portLinked,
      child: Icon(needsYou ? Icons.link_off : Icons.link, size: size, color: needsYou ? scheme.error : scheme.primary),
    );
  }
}

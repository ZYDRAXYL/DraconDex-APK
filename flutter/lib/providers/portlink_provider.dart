import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/platform/saf.dart';
import '../data/dao/port_link_dao.dart';
import '../data/services/portlink/port_drive.dart';
import '../data/services/portlink/portlink_service.dart';
import 'db_providers.dart';
import 'module_provider.dart';

/// Port Link on Android (APP Plan.md Procress 32 part 9.6). Everything here
/// answers "nothing" where there is no SAF (iOS, the PWA): the menus and the
/// Settings row are not shown there at all.
final portlinkServiceProvider = FutureProvider<PortlinkService?>((ref) async {
  if (!Saf.supported) return null;
  return PortlinkService(await ref.watch(databaseProvider.future), databaseFactory);
});

/// nexus id → its link.
final portLinksProvider = FutureProvider<Map<int, PortLink>>((ref) async {
  if (!Saf.supported) return const {};
  final db = await ref.watch(databaseProvider.future);
  return {for (final l in await PortLinkDao(db).listLinks()) l.nexusId: l};
});

/// One folder this app was given, and what is in it.
class PortDriveState {
  final String tree;
  final bool available;
  final DriveInfo? info;
  const PortDriveState(this.tree, this.available, this.info);
}

final portDrivesProvider = FutureProvider<List<PortDriveState>>((ref) async {
  final svc = await ref.watch(portlinkServiceProvider.future);
  if (svc == null) return const [];
  return [
    for (final t in await Saf.trees())
      if (await Saf.available(t)) PortDriveState(t, true, await svc.readDrive(SafDrive(t))) else PortDriveState(t, false, null),
  ];
});

/// nexus id → the last automatic sync's outcome code, when it was not a
/// clean one (`needs_choice`, `no_drive`, …): the row's mark shows it.
final portSyncStateProvider = StateProvider<Map<int, String>>((ref) => const {});

/// Syncs every linked Nexus whose drive is plugged in, asking nothing — a
/// Nexus that needs a choice is only marked. At app start and when a Nexus
/// page is left (Plan part 9.6).
Future<void> syncAllLinked(WidgetRef ref, {int? only}) async {
  final svc = await ref.read(portlinkServiceProvider.future);
  if (svc == null) return;
  final links = await ref.read(portLinksProvider.future);
  final state = Map<int, String>.of(ref.read(portSyncStateProvider));
  var changed = false;
  for (final l in links.values) {
    if (only != null && l.nexusId != only) continue;
    if (!await Saf.available(l.treeUri)) continue;
    final r = await svc.sync(l.nexusId, SafDrive(l.treeUri));
    if (r.ok) {
      state.remove(l.nexusId);
      changed |= !r.unchanged;
    } else {
      state[l.nexusId] = r.code ?? 'copy_failed';
    }
  }
  ref.read(portSyncStateProvider.notifier).state = state;
  if (changed) refreshAfterSync(ref);
}

/// After a sync rewrote a Nexus's rows, every screen reading them re-reads.
void refreshAfterSync(WidgetRef ref) {
  ref.invalidate(nexusesProvider);
  ref.invalidate(portLinksProvider);
  ref.invalidate(databaseProvider); // ponytail: re-reads everything; a per-Nexus invalidate if this ever shows up
}

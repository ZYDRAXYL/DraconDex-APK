import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/recent_views_provider.dart';
import '../../providers/shell_layout_provider.dart';
import 'builder_rail.dart';
import 'folder_views_sheet.dart';
import 'hub_sidebar.dart';
import 'view_mode_sheet.dart';

/// The Builder: the shell every "inside the app" screen is entered through —
/// the Nexus list and every module screen below it.
///
/// It has two shapes, picked from the size of the window rather than from the
/// platform (see core/layout/breakpoints.dart):
///
///  * **phone** — the screen, with the Navibar underneath it. A phone cannot
///    spare width for anything permanent, so the view switcher and the
///    folder-views list live in sheets the bar opens.
///  * **tablet and wider** — a vertical rail down the leading edge and the
///    hub panel beside it, the shape the Electron build has: the whole nest
///    stays on screen while a module is open, and the tools that the phone
///    hides in an app-bar menu get a permanent home. Same Flutter code and
///    the same screens, so this is what the tablet APK and the iPad build get
///    as well as the PWA's mobile lane.
///
/// Screens keep their own Scaffold (app bar, FAB) in both shapes; this one
/// only adds the chrome around them.
class BuilderShell extends ConsumerWidget {
  final Widget child;

  /// Current router path, handed down from the ShellRoute builder's own
  /// GoRouterState rather than looked up again below — the rail marks "home"
  /// with it and the hub panel resolves which tree row is open from it.
  final String location;

  const BuilderShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ddxLayoutOf(context).hasRail) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BuilderNavibar(location: location),
      );
    }
    return _RailShell(location: location, child: child);
  }
}

/// The tablet/desktop arrangement: rail | hub panel | content.
///
/// Stateful only to own the Scaffold key — on a window too narrow for three
/// columns the hub panel becomes a drawer, and something has to be able to
/// open it from the rail.
class _RailShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const _RailShell({required this.child, required this.location});

  @override
  ConsumerState<_RailShell> createState() => _RailShellState();
}

class _RailShellState extends ConsumerState<_RailShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(shellLayoutProvider);
    final railWidth = shell.railExtended ? kRailExtendedWidth : kRailWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        // What the panel may take without squeezing the content pane down to
        // a strip. On a roomy window this is simply the width the user
        // dragged it to.
        final available = constraints.maxWidth - railWidth - kMinContentWidth;
        final panelWidth = math.min(shell.hubWidth, available);
        final fitsBeside = panelWidth >= kHubPanelMinWidth;
        final showPanel = shell.hubVisible && fitsBeside;

        void toggleHub() {
          if (fitsBeside) {
            ref.read(shellLayoutProvider.notifier).toggleHub();
          } else {
            final scaffold = _scaffoldKey.currentState;
            if (scaffold == null) return;
            // closeDrawer(), not Navigator.pop(): this closure was built above
            // the Scaffold, so the nearest Navigator to it is the router's —
            // popping that would walk the app back a screen.
            if (scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
            } else {
              scaffold.openDrawer();
            }
          }
        }

        void showHub() {
          if (fitsBeside) {
            ref.read(shellLayoutProvider.notifier).setHubVisible(true);
          } else if (_scaffoldKey.currentState?.isDrawerOpen == false) {
            _scaffoldKey.currentState?.openDrawer();
          }
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: fitsBeside
              ? null
              : Drawer(
                  width: math.min(shell.hubWidth + 32, constraints.maxWidth * 0.85),
                  child: HubSidebar(
                    location: widget.location,
                    onClose: () => _scaffoldKey.currentState?.closeDrawer(),
                  ),
                ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BuilderRail(
                location: widget.location,
                hubVisible: showPanel,
                onToggleHub: toggleHub,
                onShowHub: showHub,
              ),
              if (showPanel) ...[
                SizedBox(
                  width: panelWidth,
                  child: HubSidebar(
                    location: widget.location,
                    onClose: () => ref.read(shellLayoutProvider.notifier).setHubVisible(false),
                  ),
                ),
                const HubResizeHandle(),
              ],
              // ClipRect so a screen's own transitions stay inside the pane
              // instead of drawing over the rail.
              Expanded(child: ClipRect(child: widget.child)),
            ],
          ),
        );
      },
    );
  }
}

/// The Builder's bottom bar, on phone-shaped windows only. Only "home" is a
/// destination — the other two open sheets — so this is a bar of actions
/// rather than a [NavigationBar] with a selected index that would lie about
/// where the user is.
class BuilderNavibar extends ConsumerWidget {
  final String location;

  const BuilderNavibar({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(builderViewModeProvider);
    final recentCount = ref.watch(recentViewsProvider).length;
    final atHome = location == '/';

    return BottomAppBar(
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavibarButton(
              icon: atHome ? Icons.home : Icons.home_outlined,
              label: l10n.builderNavHome,
              highlighted: atHome,
              onTap: () => context.go('/'),
            ),
            _NavibarButton(
              icon: mode.icon,
              label: l10n.builderNavView,
              onTap: () => showViewModeSheet(context),
            ),
            _NavibarButton(
              icon: Icons.folder_copy_outlined,
              label: l10n.builderNavFolders,
              badgeCount: recentCount,
              onTap: () => showFolderViewsSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavibarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final int badgeCount;

  const _NavibarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlighted ? scheme.primary : scheme.onSurface.withValues(alpha: 0.75);
    final iconWidget = Icon(icon, size: 22, color: color);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                badgeCount > 0
                    ? Badge.count(count: badgeCount, child: iconWidget)
                    : iconWidget,
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

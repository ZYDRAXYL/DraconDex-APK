import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/services/bundle_service.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/recent_views_provider.dart';
import '../../providers/shell_layout_provider.dart';
import '../hub/dialogs/new_module_sheet.dart';
import 'builder_rail.dart';
import 'hub_location.dart';
import 'hub_sidebar.dart';
import 'open_pages.dart';
import 'shell_sheets.dart';

/// The Builder: the shell every "inside the app" screen is entered through —
/// the Nexus list, every module screen below it, and search.
///
/// It has two shapes, picked from the size of the window rather than from the
/// platform (see core/layout/breakpoints.dart):
///
///  * **phone** — the screen, with the five-slot Navibar underneath it (APK
///    V3, APP docs/APK-V3.md §10.1). The Navibar and the screen's app bar
///    step aside while the user scrolls down and come back on the way up
///    (§10.5) — a long page gets the whole screen without a button for it.
///  * **tablet and wider** — a vertical rail down the leading edge, the hub
///    panel beside it and a row of open-page tabs over the content, the shape
///    the Electron build has. Same Flutter code and the same screens, so this
///    is what the tablet APK and the iPad build get as well as the PWA's
///    wide lane.
///
/// Screens keep their own Scaffold (app bar, FAB) in both shapes; this one
/// only adds the chrome around them.
class BuilderShell extends ConsumerStatefulWidget {
  final Widget child;

  /// Current router path, handed down from the ShellRoute builder's own
  /// GoRouterState rather than looked up again below — the rail and the
  /// Navibar mark where the user is with it, and the hub panel resolves which
  /// tree row is open from it.
  final String location;

  const BuilderShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<BuilderShell> createState() => _BuilderShellState();
}

class _BuilderShellState extends ConsumerState<BuilderShell> {
  @override
  void didUpdateWidget(BuilderShell old) {
    super.didUpdateWidget(old);
    // A new page starts with its chrome showing, whatever the last one was
    // scrolled to. After the frame: this runs mid-build, where a provider
    // must not change.
    if (old.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chromeVisibleProvider.notifier).state = true;
      });
    }
  }

  /// Down hides, up shows, and the top of a page always shows. Only a
  /// vertical scroll the user's finger is driving counts — a horizontal
  /// strip, a fling coasting to a stop, or a list scrolled by code says
  /// nothing about which way they are reading. A few pixels of slack keep a
  /// tap with a wobble in it from flicking the bars.
  bool _onScroll(ScrollNotification n) {
    // iOS keeps its tab bar while scrolling (APP docs/REDESIGN.md C3).
    if (context.isIosStyle) return false;
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final chrome = ref.read(chromeVisibleProvider.notifier);
    final delta = n.scrollDelta ?? 0;
    if (n.metrics.extentBefore <= 0) {
      chrome.state = true;
    } else if (n.dragDetails != null && delta.abs() > 2) {
      chrome.state = delta < 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (ddxLayoutOf(context).hasRail) {
      // A tablet keeps its chrome. Bars a phone-shaped window hid — before a
      // rotation or a Split View resize made it this one — come back.
      if (!ref.read(chromeVisibleProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(chromeVisibleProvider.notifier).state = true;
        });
      }
      return _RailShell(location: widget.location, child: widget.child);
    }
    final visible = ref.watch(chromeVisibleProvider);
    return Scaffold(
      body: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: visible ? BuilderNavibar(location: widget.location) : const SizedBox(width: double.infinity),
      ),
    );
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OpenPagesBar(location: widget.location),
                    // ClipRect so a screen's own transitions stay inside the
                    // pane instead of drawing over the rail or the tabs.
                    Expanded(child: ClipRect(child: widget.child)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The Builder's bottom bar, on phone-shaped windows only — the five slots
/// of APP docs/APK-V3.md §10.1: Nest · Search · Open pages · Tools · More.
/// Two are places (marked when the user is there), three open sheets, so this
/// is a bar of buttons rather than a [NavigationBar] whose selected index
/// would claim a place for a sheet.
class BuilderNavibar extends ConsumerWidget {
  final String location;

  const BuilderNavibar({super.key, required this.location});

  /// Where "Nest" goes from [location]: inside a Nexus, its root — the top
  /// of the tree the user is in — and from there, or anywhere else, the
  /// Nexus list.
  static String nestTarget(String location) {
    final here = HubLocation.parse(location);
    if (here.nexusId != null && here.moduleId != null) return '/hub/${here.nexusId}';
    return '/';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final openCount = ref.watch(recentViewsProvider).length;
    final here = HubLocation.parse(location);
    final atNest = location == '/' || (here.nexusId != null && here.moduleId == null);
    final atSearch = location == '/search';

    final row = SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavibarButton(
              icon: atNest ? Icons.account_tree : Icons.account_tree_outlined,
              label: l10n.navNest,
              highlighted: atNest,
              onTap: () => context.go(nestTarget(location)),
            ),
            _NavibarButton(
              icon: Icons.search,
              label: l10n.navSearch,
              highlighted: atSearch,
              onTap: () {
                if (!atSearch) context.push('/search');
              },
            ),
            _NavibarButton(
              icon: Icons.filter_none,
              label: l10n.navOpenPages,
              badgeCount: openCount,
              onTap: () => showOpenPagesSheet(context, currentLocation: location),
            ),
            _NavibarButton(
              icon: Icons.handyman_outlined,
              label: l10n.navTools,
              onTap: () => showToolsSheet(context),
            ),
            _NavibarButton(
              icon: Icons.more_horiz,
              label: l10n.navMore,
              onTap: () => showMoreSheet(context, onAddGuide: (nx) async {
                final spec = await BundleService.loadGuide(Localizations.localeOf(context).languageCode);
                if (context.mounted) await createFromTemplate(context, ref, nx, null, spec);
              }),
            ),
          ],
        ),
      );
    if (context.isIosStyle) {
      // The Apple tab bar (C3): translucent over the page, blurred, a hairline
      // on top — the same five destinations.
      final ddx = context.ddx;
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ddx.iosBar,
              border: Border(top: BorderSide(color: ddx.iosSeparator, width: 0.5)),
            ),
            child: Padding(padding: const EdgeInsets.only(top: 4), child: row),
          ),
        ),
      );
    }
    return BottomAppBar(padding: EdgeInsets.zero, child: row);
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
    final ios = context.isIosStyle;
    final color = highlighted
        ? (ios ? context.ddx.iosTint : scheme.primary)
        : (ios ? context.ddx.textMuted : scheme.onSurface.withValues(alpha: 0.75));
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../providers/builder_view_provider.dart';
import '../../providers/recent_views_provider.dart';
import '../../providers/shell_layout_provider.dart';

/// The tablet shell's vertical nav rail — the Flutter answer to the Electron
/// build's `#nav-sidebar`, and the reason a tablet does not simply get the
/// phone's bottom bar stretched wide.
///
/// Same three Builder actions the Navibar has (home, view mode, folder
/// views), plus the three tools that only fit in the phone's app bar (tags,
/// colours, settings), plus the two pieces of chrome the phone has nowhere to
/// put: the hub panel toggle and the labels toggle. Order matches the desktop
/// rail — brand and navigation at the top, tools pinned to the bottom.
class BuilderRail extends ConsumerWidget {
  final String location;

  /// Flips the hub panel on and off. The shell owns this because the panel is
  /// a column beside the content on a roomy window and a drawer over it on a
  /// cramped one, and the rail should not have to care which.
  final VoidCallback onToggleHub;

  /// Makes sure the panel is on screen — used by the folder-views button,
  /// which reveals a section of it rather than opening a sheet.
  final VoidCallback onShowHub;

  final bool hubVisible;

  const BuilderRail({
    super.key,
    required this.location,
    required this.onToggleHub,
    required this.onShowHub,
    required this.hubVisible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shell = ref.watch(shellLayoutProvider);
    final mode = ref.watch(builderViewModeProvider);
    final recentCount = ref.watch(recentViewsProvider).length;
    final atHome = location == '/';
    final extended = shell.railExtended;

    // Material, not a bare Container: every row below is an InkWell, and ink
    // splashes need a Material of their own to land on once this panel paints
    // its own surface colour over the Scaffold's.
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: extended ? kRailExtendedWidth : kRailWidth,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor)),
        ),
        child: SafeArea(
          right: false,
          // The rail runs the full height of the window, so it — not the
          // content pane's own AppBar — is what sits under the status bar and
          // the home indicator here.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keeps the tools pinned to the bottom on a normal window while
              // still scrolling rather than overflowing on a short one (a large
              // ui scale can double every row's height).
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        _RailBrand(extended: extended),
                        _RailButton(
                          icon: hubVisible ? Icons.menu_open : Icons.menu,
                          label: hubVisible ? l10n.hubPanelHide : l10n.hubPanelShow,
                          extended: extended,
                          onTap: onToggleHub,
                        ),
                        const Divider(height: 9, indent: 12, endIndent: 12),
                        _RailButton(
                          icon: atHome ? Icons.home : Icons.home_outlined,
                          label: l10n.builderNavHome,
                          extended: extended,
                          highlighted: atHome,
                          onTap: () => context.go('/'),
                        ),
                        _ViewModeRailButton(current: mode, extended: extended),
                        _RailButton(
                          icon: Icons.folder_copy_outlined,
                          label: l10n.builderNavFolders,
                          extended: extended,
                          badgeCount: recentCount,
                          onTap: () {
                            onShowHub();
                            ref.read(shellLayoutProvider.notifier).setRecentSectionOpen(true);
                          },
                        ),
                        const Spacer(),
                        const Divider(height: 9, indent: 12, endIndent: 12),
                        _RailButton(
                          icon: Icons.sell_outlined,
                          label: l10n.moduleGlobalTags,
                          extended: extended,
                          onTap: () => context.push('/tags'),
                        ),
                        _RailButton(
                          icon: Icons.palette_outlined,
                          label: l10n.moduleColors,
                          extended: extended,
                          onTap: () => context.push('/colors'),
                        ),
                        _RailButton(
                          icon: Icons.settings_outlined,
                          label: l10n.moduleSettings,
                          extended: extended,
                          onTap: () => context.push('/settings'),
                        ),
                        _RailButton(
                          icon: extended ? Icons.chevron_left : Icons.chevron_right,
                          label: extended ? l10n.railCollapse : l10n.railExpand,
                          extended: extended,
                          onTap: () => ref.read(shellLayoutProvider.notifier).toggleRailExtended(),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The app mark at the top of the rail, which doubles as "back to the Nexus
/// list" exactly like the desktop rail's logo button. Light themes get the
/// black symbol, dark ones the white — the same swap the Electron CSS makes
/// per theme.
class _RailBrand extends StatelessWidget {
  final bool extended;

  const _RailBrand({required this.extended});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = theme.brightness == Brightness.dark
        ? 'assets/images/DraconDex-SymbolWhite.png'
        : 'assets/images/DraconDex-SymbolBlack.png';
    final logo = Image.asset(asset, width: 28, height: 28, fit: BoxFit.contain);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => context.go('/'),
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: AppLocalizations.of(context)!.appName,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: extended
                ? Row(
                    children: [
                      logo,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  )
                : Center(child: logo),
          ),
        ),
      ),
    );
  }
}

/// View mode opens a menu anchored on the rail rather than the phone's bottom
/// sheet: a sheet sliding up from the far edge of a 12" screen to answer a
/// button on the left of it reads as a different screen answering.
class _ViewModeRailButton extends ConsumerWidget {
  final BuilderViewMode current;
  final bool extended;

  const _ViewModeRailButton({required this.current, required this.extended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    String labelFor(BuilderViewMode mode) => switch (mode) {
          BuilderViewMode.list => l10n.viewModeList,
          BuilderViewMode.grid => l10n.viewModeGrid,
          BuilderViewMode.compact => l10n.viewModeCompact,
        };

    return PopupMenuButton<BuilderViewMode>(
      tooltip: l10n.viewModeTitle,
      position: PopupMenuPosition.under,
      onSelected: (mode) => ref.read(builderViewModeProvider.notifier).set(mode),
      itemBuilder: (_) => [
        for (final mode in BuilderViewMode.values)
          PopupMenuItem<BuilderViewMode>(
            value: mode,
            child: Row(
              children: [
                Icon(mode.icon, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(labelFor(mode))),
                if (mode == current) const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
      child: _RailItemBody(
        icon: current.icon,
        label: l10n.builderNavView,
        extended: extended,
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool extended;
  final bool highlighted;
  final int badgeCount;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.extended,
    this.highlighted = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: label,
        // An icon-only rail has nothing but the tooltip to explain itself;
        // once the labels are showing it would only repeat them.
        excludeFromSemantics: extended,
        child: _RailItemBody(
          icon: icon,
          label: label,
          extended: extended,
          highlighted: highlighted,
          badgeCount: badgeCount,
        ),
      ),
    );
  }
}

/// The visual half of a rail row, without a gesture of its own — so it can
/// also be handed to a [PopupMenuButton], which needs to own the tap.
class _RailItemBody extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final bool highlighted;
  final int badgeCount;

  const _RailItemBody({
    required this.icon,
    required this.label,
    required this.extended,
    this.highlighted = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlighted ? scheme.primary : scheme.onSurface.withValues(alpha: 0.75);
    Widget iconWidget = Icon(icon, size: 22, color: color);
    if (badgeCount > 0) iconWidget = Badge.count(count: badgeCount, child: iconWidget);

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: color);

    return Container(
      width: double.infinity,
      decoration: highlighted
          ? BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            )
          : null,
      padding: extended
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 14)
          : const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: extended
          ? Row(
              children: [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(height: 2),
                Text(
                  label,
                  // Two lines, because 76dp of rail is not enough for the
                  // longer labels on one: driving the built app showed
                  // "Folder Views" and "Hide hub panel" arriving as "Folder
                  // Vie…" and "Hide hub …", which is a worse way to spend the
                  // space than a second line.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ],
            ),
    );
  }
}

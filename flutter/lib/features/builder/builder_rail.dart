import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/layout/breakpoints.dart';
import '../../data/models/module_model.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/shell_layout_provider.dart';
import '../../widgets/row_menu.dart';
import 'builder_shell.dart';
import 'hub_location.dart';
import 'shell_sheets.dart';

/// The tablet shell's vertical nav rail — the Flutter answer to the Electron
/// build's Activity Bar (V5.md §11.9), and the reason a tablet does not simply
/// get the phone's bottom bar stretched wide.
///
/// APK V3 (APP docs/APK-V3.md §10.1): the places — Nest, Search, Labels —
/// and the Tools menu, then the modules pinned in the Nexus the user is in,
/// with Settings and the label toggle pinned to the bottom. The phone keeps
/// Labels and Settings behind its "More" slot; a rail has the room.
class BuilderRail extends ConsumerWidget {
  final String location;

  /// Flips the hub panel on and off. The shell owns this because the panel is
  /// a column beside the content on a roomy window and a drawer over it on a
  /// cramped one, and the rail should not have to care which.
  final VoidCallback onToggleHub;

  final bool hubVisible;

  const BuilderRail({
    super.key,
    required this.location,
    required this.onToggleHub,
    required this.hubVisible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shell = ref.watch(shellLayoutProvider);
    final here = HubLocation.parse(location);
    final atNest = location == '/' || (here.nexusId != null && here.moduleId == null);
    final pinned = here.nexusId == null
        ? const <ModuleModel>[]
        : ref.watch(pinnedModulesProvider(here.nexusId!)).valueOrNull ?? const <ModuleModel>[];
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
                          icon: atNest ? Icons.account_tree : Icons.account_tree_outlined,
                          label: l10n.navNest,
                          extended: extended,
                          highlighted: atNest,
                          onTap: () => context.go(BuilderNavibar.nestTarget(location)),
                        ),
                        _RailButton(
                          icon: Icons.search,
                          label: l10n.navSearch,
                          extended: extended,
                          highlighted: location == '/search',
                          onTap: () {
                            if (location != '/search') context.push('/search');
                          },
                        ),
                        _RailButton(
                          icon: Icons.sell_outlined,
                          label: l10n.moduleGlobalTags,
                          extended: extended,
                          onTap: () => context.push('/tags'),
                        ),
                        _RailMenuButton(
                          icon: Icons.handyman_outlined,
                          label: l10n.navTools,
                          extended: extended,
                          actions: toolsActions(context),
                        ),
                        if (pinned.isNotEmpty) ...[
                          const Divider(height: 9, indent: 12, endIndent: 12),
                          for (final m in pinned)
                            _RailButton(
                              icon: m.kindInfo.icon,
                              label: m.name,
                              extended: extended,
                              highlighted: here.moduleId == m.id && here.itemKey == null,
                              onTap: () => context.go('/hub/${m.nexusRef}/module/${m.id}'),
                            ),
                        ],
                        const Spacer(),
                        const Divider(height: 9, indent: 12, endIndent: 12),
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

/// A rail entry that opens a menu anchored on the rail rather than the
/// phone's bottom sheet: a sheet sliding up from the far edge of a 12" screen
/// to answer a button on the left of it reads as a different screen
/// answering.
class _RailMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final List<RowAction> actions;

  const _RailMenuButton({
    required this.icon,
    required this.label,
    required this.extended,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RowAction>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (a) => a.onTap(),
      itemBuilder: (_) => [
        for (final a in actions)
          PopupMenuItem<RowAction>(
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(a.label)),
              ],
            ),
          ),
      ],
      child: _RailItemBody(icon: icon, label: label, extended: extended),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool extended;
  final bool highlighted;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.extended,
    this.highlighted = false,
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

  const _RailItemBody({
    required this.icon,
    required this.label,
    required this.extended,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlighted ? scheme.primary : scheme.onSurface.withValues(alpha: 0.75);
    final iconWidget = Icon(icon, size: 22, color: color);

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
                  // "Hide hub panel" arriving as "Hide hub …", which is a
                  // worse way to spend the space than a second line.
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

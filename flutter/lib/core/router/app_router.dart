import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/builder/builder_shell.dart';
import '../../features/hub/nexus_list_screen.dart';
import '../../features/hub/module_explorer_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/colors/colors_screen.dart';
import '../../features/settings/settings_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    // Everything "inside the app" is entered through the Builder shell, which
    // adds the Navibar under the screen. The hub routes are nested (rather
    // than three flat paths) so jumping straight to a deep location — from
    // the Navibar's folder-views list — rebuilds the whole stack under it and
    // the back button still walks up the tree.
    ShellRoute(
      builder: (ctx, state, child) => BuilderShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => const NexusListScreen(),
          routes: [
            GoRoute(
              path: 'hub/:nexusId',
              builder: (ctx, state) => ModuleExplorerScreen(
                nexusId: int.parse(state.pathParameters['nexusId']!),
              ),
              routes: [
                GoRoute(
                  path: 'module/:moduleId',
                  builder: (ctx, state) => ModuleExplorerScreen(
                    nexusId: int.parse(state.pathParameters['nexusId']!),
                    moduleId: int.parse(state.pathParameters['moduleId']!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (ctx, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/colors',
      builder: (ctx, state) => const ColorsScreen(),
    ),
    GoRoute(
      path: '/tags',
      builder: (ctx, state) => const TagsScreen(),
    ),
  ],
);

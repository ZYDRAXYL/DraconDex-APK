import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/builder/builder_shell.dart';
import '../../features/hub/nexus_list_screen.dart';
import '../../features/hub/module_explorer_screen.dart';
import '../../features/search/search_screen.dart';
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
    // than flat paths) so jumping straight to a deep location — an open page,
    // a search result — rebuilds the whole stack under it and the back
    // button still walks up the tree.
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
                  routes: [
                    // An element page (APP docs/APK-V3.md §10.3).
                    GoRoute(
                      path: 'item/:itemKey',
                      builder: (ctx, state) => ModuleExplorerScreen(
                        nexusId: int.parse(state.pathParameters['nexusId']!),
                        moduleId: int.parse(state.pathParameters['moduleId']!),
                        itemKey: state.pathParameters['itemKey'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/search',
          builder: (ctx, state) => const SearchScreen(),
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

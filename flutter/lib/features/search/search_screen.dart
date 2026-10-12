import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/search_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../widgets/ddx_list.dart';
import '../builder/open_pages.dart';
import '../hub/dialogs/nexus_dialog.dart';
import '../../widgets/ddx_glass.dart';
import '../../widgets/ddx_icon_button.dart';

/// The one search field of APK V3 (APP docs/APK-V3.md §9.2, §13 item 14):
/// results in three groups — things (names of modules and elements), content
/// (text inside them), and commands (the app's own actions). Every Nexus is
/// searched; a result says which module it is in.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

/// An app command the search offers by name.
class _Command {
  final String label;
  final IconData icon;
  final void Function(BuildContext context) run;

  const _Command(this.label, this.icon, this.run);
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  SearchService? _service;

  /// The query the results below belong to — a slow search for an older
  /// query must not overwrite a newer one's results.
  String _shown = '';
  List<SearchHit> _things = const [];
  List<SearchHit> _content = const [];
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(text));
    setState(() {});
  }

  Future<void> _run(String text) async {
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _shown = '';
        _things = const [];
        _content = const [];
        _busy = false;
      });
      return;
    }
    final db = await ref.read(databaseProvider.future);
    final service = _service ??= SearchService(db);
    setState(() => _busy = true);
    final things = await service.things(q);
    final content = await service.content(q);
    if (!mounted || _controller.text.trim() != q) return;
    setState(() {
      _shown = q;
      _things = things;
      _content = content;
      _busy = false;
    });
  }

  List<_Command> _commands(AppLocalizations l10n) => [
        _Command(l10n.newNexusTooltip, Icons.add_circle_outline, (context) async {
          await showDdxDialog(context: context, builder: (_) => const NexusDialog());
          ref.invalidate(nexusesProvider);
          if (context.mounted) context.go('/');
        }),
        _Command(l10n.openPagesTitle, Icons.filter_none,
            (context) => showOpenPagesSheet(context, currentLocation: '/search')),
        _Command(l10n.navNest, Icons.account_tree_outlined, (context) => context.go('/')),
        _Command(l10n.moduleColors, Icons.palette_outlined, (context) => context.push('/colors')),
        _Command(l10n.moduleGlobalTags, Icons.sell_outlined, (context) => context.push('/tags')),
        _Command(l10n.moduleSettings, Icons.settings_outlined, (context) => context.push('/settings')),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = _controller.text.trim().toLowerCase();
    final commands = q.isEmpty
        ? const <_Command>[]
        : _commands(l10n).where((c) => c.label.toLowerCase().contains(q)).toList();
    final stale = _shown.toLowerCase() != q;
    final nothing = q.isNotEmpty && !stale && !_busy && _things.isEmpty && _content.isEmpty && commands.isEmpty;

    return Scaffold(
      appBar: DdxGlassBar(child: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : DdxIconButton(
                    icon: Icons.clear,
                    tooltip: l10n.btnClose,
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
      )),
      // Three groups, each with its count and folding (UX-LAYOUT §12.4),
      // their rows built as they scroll in.
      body: CustomScrollView(
        slivers: [
          if (_busy) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (nothing) SliverToBoxAdapter(child: DdxEmptyState(icon: Icons.search_off, message: l10n.searchEmpty)),
          if (_things.isNotEmpty)
            DdxListSection.sliver(
              storageId: 'search-things',
              title: l10n.searchThings,
              count: _things.length,
              itemCount: _things.length,
              itemBuilder: (context, i) => _hitRow(context, _things[i]),
            ),
          if (_content.isNotEmpty)
            DdxListSection.sliver(
              storageId: 'search-content',
              title: l10n.searchContent,
              count: _content.length,
              itemCount: _content.length,
              itemBuilder: (context, i) => _hitRow(context, _content[i], showSnippet: true),
            ),
          if (commands.isNotEmpty)
            DdxListSection.sliver(
              storageId: 'search-commands',
              title: l10n.searchCommands,
              count: commands.length,
              itemCount: commands.length,
              itemBuilder: (context, i) => DdxListTile(
                icon: commands[i].icon,
                title: commands[i].label,
                onTap: () => commands[i].run(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// A result: what it is, its name, and where it is (plus the matching text,
/// for a content hit).
Widget _hitRow(BuildContext context, SearchHit hit, {bool showSnippet = false}) {
  final where = hit.isModule ? null : hit.moduleName;
  final meta = showSnippet && hit.snippet != null && hit.snippet!.isNotEmpty ? [?where, hit.snippet!].join(' · ') : where;
  return DdxListTile(
    icon: hit.isModule ? Icons.folder_outlined : Icons.article_outlined,
    title: hit.title.isEmpty ? '—' : hit.title,
    meta: meta,
    onTap: () => context.push(hit.location),
  );
}

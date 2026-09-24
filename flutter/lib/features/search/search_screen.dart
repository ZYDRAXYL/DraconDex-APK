import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/search_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../builder/open_pages.dart';
import '../hub/dialogs/nexus_dialog.dart';

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
          await showDialog(context: context, builder: (_) => const NexusDialog());
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
    final theme = Theme.of(context);
    final q = _controller.text.trim().toLowerCase();
    final commands = q.isEmpty
        ? const <_Command>[]
        : _commands(l10n).where((c) => c.label.toLowerCase().contains(q)).toList();
    final stale = _shown.toLowerCase() != q;
    final nothing = q.isNotEmpty && !stale && !_busy && _things.isEmpty && _content.isEmpty && commands.isEmpty;

    return Scaffold(
      appBar: AppBar(
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
                : IconButton(
                    icon: const Icon(Icons.clear),
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
      ),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (nothing)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.searchEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
          if (_things.isNotEmpty) ...[
            _GroupHeader(label: l10n.searchThings),
            for (final h in _things) _HitTile(hit: h),
          ],
          if (_content.isNotEmpty) ...[
            _GroupHeader(label: l10n.searchContent),
            for (final h in _content) _HitTile(hit: h, showSnippet: true),
          ],
          if (commands.isNotEmpty) ...[
            _GroupHeader(label: l10n.searchCommands),
            for (final c in commands)
              ListTile(
                leading: Icon(c.icon),
                title: Text(c.label),
                onTap: () => c.run(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  final SearchHit hit;
  final bool showSnippet;

  const _HitTile({required this.hit, this.showSnippet = false});

  @override
  Widget build(BuildContext context) {
    final where = hit.isModule ? null : hit.moduleName;
    final subtitle = showSnippet && hit.snippet != null && hit.snippet!.isNotEmpty
        ? [?where, hit.snippet!].join(' · ')
        : where;
    return ListTile(
      leading: Icon(hit.isModule ? Icons.folder_outlined : Icons.article_outlined),
      title: Text(hit.title.isEmpty ? '—' : hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => context.push(hit.location),
    );
  }
}

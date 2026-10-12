import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/dao/module_dao.dart';
import '../../data/models/color_model.dart';
import '../../data/services/bundle_service.dart';
import '../../providers/color_provider.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';
import '../../providers/navigation_providers.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/ddx_card.dart';
import '../../widgets/ddx_field.dart';
import '../../widgets/ddx_glass.dart';
import '../../widgets/ddx_segmented.dart';
import '../builder/builder_shell.dart';
import 'dialogs/artisan_sheet.dart';

/// Where "New Nexus" goes (APP Plan.md Procress 25 part 5, docs/UX-LAYOUT.md
/// §14.7) — the phone's take on the desktop's Unity-style window: two steps
/// instead of two panes. Step 1 is this screen, the templates full-screen
/// as three shelves in one scroll (Blank first, then Genre, then Classic —
/// genre before classic as on the desktop) with a segmented control that
/// jumps between them, so any template is one tap; tapping one opens step 2, the form
/// in a sheet: name (a free default, selected, so typing replaces it), memo,
/// colour, and "Create App Docs" — ticked by default only for the first
/// Nexus. APK has no tour, so the desktop's second checkbox is not here.
///
/// Create makes the Nexus, then the template, then App Docs, then opens the
/// new Nexus. A template that fails does not take the Nexus with it: the
/// Nexus stays and a snackbar offers Retry.
class NewNexusScreen extends ConsumerStatefulWidget {
  const NewNexusScreen({super.key});

  static const route = '/new-nexus';

  /// What builds a template into a new Nexus — swapped by tests to make one fail.
  @visibleForTesting
  static Future<void> Function(Database db, int nexusId, Map<String, dynamic> spec) applySpec = _apply;

  static Future<void> _apply(Database db, int nexusId, Map<String, dynamic> spec) async {
    await BundleService.create(db, nexusId, null, spec);
  }

  @override
  ConsumerState<NewNexusScreen> createState() => _NewNexusScreenState();
}

enum _Cat { blank, genre, classic }

/// The form's answer.
typedef NewNexusRequest = ({String name, String? memo, int? colorId, bool appDocs});

/// The first free "New Nexus", "New Nexus 2", … among [taken].
String freeNexusName(String base, Iterable<String> taken) {
  final t = {for (final n in taken) n.trim().toLowerCase()};
  if (!t.contains(base.toLowerCase())) return base;
  for (var i = 2;; i++) {
    if (!t.contains('$base $i'.toLowerCase())) return '$base $i';
  }
}

class _NewNexusScreenState extends ConsumerState<NewNexusScreen> {
  _Cat _cat = _Cat.blank;
  Future<List<Map<String, dynamic>>>? _bundles;
  bool _busy = false;
  final _keys = {for (final c in _Cat.values) c: GlobalKey()};

  /// Jump to a shelf — the shelves are one scroll, so every template is
  /// a tap away and the segmented control only moves the view.
  void _jump(_Cat c) {
    setState(() => _cat = c);
    final ctx = _keys[c]!.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Which shelf the top of the view is on.
  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.depth != 0) return false;
    final top = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero).dy ?? 0;
    var at = _Cat.blank;
    for (final c in _Cat.values) {
      final box = _keys[c]!.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.localToGlobal(Offset.zero).dy - top < 220) at = c;
    }
    if (at != _cat) setState(() => _cat = at);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    _bundles ??= BundleService.loadBundles(Localizations.localeOf(context).languageCode);
    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260, mainAxisExtent: 150, mainAxisSpacing: 10, crossAxisSpacing: 10);
    Widget head(_Cat c, String text) => SliverToBoxAdapter(
          child: Padding(
            key: _keys[c],
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(text, style: Theme.of(context).textTheme.titleSmall),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.newNexusTitle)),
      body: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(l.nexusPickTemplate, style: TextStyle(color: context.ddx.textMuted)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: DdxSegmented<_Cat>(
              segments: [
                DdxSegment(value: _Cat.blank, label: l.nexusTemplateBlank),
                DdxSegment(value: _Cat.genre, label: l.bundleTabGenre),
                DdxSegment(value: _Cat.classic, label: l.bundleTabClassic),
              ],
              selected: _cat,
              onChanged: _jump,
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bundles,
              builder: (context, snap) {
                final all = snap.data ?? const <Map<String, dynamic>>[];
                // genre before classic, as on the desktop (UX-LAYOUT §14.2)
                final genre = [for (final b in all) if ((b['group'] ?? 'genre') == 'genre') b];
                final classic = [for (final b in all) if (b['group'] == 'classic') b];
                Widget shelf(List<Map<String, dynamic>> bs) => SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate: grid,
                        delegate: SliverChildListDelegate([
                          for (final b in bs)
                            BundleCard(
                              key: ValueKey('nexus-tpl-${b['id']}'),
                              bundle: b,
                              selected: false,
                              onTap: _busy ? () {} : () => _pick(b),
                            ),
                        ]),
                      ),
                    );
                return NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(slivers: [
                    head(_Cat.blank, l.nexusTemplateBlank),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate: grid,
                        delegate: SliverChildListDelegate([_BlankCard(onTap: _busy ? null : () => _pick(null))]),
                      ),
                    ),
                    if (genre.isNotEmpty) ...[head(_Cat.genre, l.bundleTabGenre), shelf(genre)],
                    if (classic.isNotEmpty) ...[head(_Cat.classic, l.bundleTabClassic), shelf(classic)],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// Step 2: the form, then the build.
  Future<void> _pick(Map<String, dynamic>? bundle) async {
    final l = AppLocalizations.of(context)!;
    final db = await ref.read(databaseProvider.future);
    final existing = await ModuleDao(db).getNexuses();
    if (!mounted) return;
    final req = await showDdxSheet<NewNexusRequest>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => NewNexusForm(
        template: bundle == null ? l.nexusTemplateBlank : '${bundle['name']}',
        taken: [for (final n in existing) n.name],
        defaultName: freeNexusName(l.newNexusTitle, [for (final n in existing) n.name]),
      ),
    );
    if (req == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _create(db, bundle, req);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(Database db, Map<String, dynamic>? bundle, NewNexusRequest req) async {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);

    final int id;
    try {
      id = await ModuleDao(db).createNexus(name: req.name, memo: req.memo, colorId: req.colorId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l.saveFailedMessage} $e')));
      return;
    }

    // template first (into the root), then App Docs (its own folder) —
    // each step tried on its own, so a broken template still gets the guide
    final pending = <Future<Map<String, dynamic>> Function()>[
      if (bundle != null) () async => {...((bundle['spec'] as Map?) ?? const {}).cast<String, dynamic>(), 'name': bundle['name'], 'icon': ?bundle['icon']},
      if (req.appDocs) () => BundleService.loadGuide(locale),
    ];
    /// Builds what is still pending; true when something failed.
    Future<bool> run() async {
      final failed = <Future<Map<String, dynamic>> Function()>[];
      for (final step in pending) {
        try {
          await NewNexusScreen.applySpec(db, id, await step());
        } catch (_) {
          failed.add(step);
        }
      }
      pending
        ..clear()
        ..addAll(failed);
      container.invalidate(nexusesProvider);
      container.invalidate(moduleChildrenProvider);
      container.invalidate(nexusIndexProvider(id));
      container.invalidate(pinnedModulesProvider(id));
      return failed.isNotEmpty;
    }

    // Shown on the new Nexus's page — its own messenger, so the snack bar
    // lifts that page's FAB (BuilderShell.messengerKey).
    void offerRetry() => (BuilderShell.messengerKey.currentState ?? messenger).showSnackBar(SnackBar(
          content: Text(l.nexusTemplateFailed),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: l.btnRetry,
            onPressed: () async {
              if (await run()) offerRetry();
            },
          ),
        ));

    final failed = await run();
    router.go('/hub/$id');
    if (failed) {
      await WidgetsBinding.instance.endOfFrame;
      offerRetry();
    }
  }
}

class _BlankCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _BlankCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ddx = context.ddx;
    return DdxCard(
      key: const ValueKey('nexus-tpl-blank'),
      kind: DdxCardKind.link,
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 48,
          color: ddx.palette.raised,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Icon(Icons.add, color: ddx.palette.t1, size: 22),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.nexusTemplateBlank, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Expanded(
                child: Text(l.nexusTemplateBlankDesc,
                    overflow: TextOverflow.fade, style: TextStyle(fontSize: 11.5, color: ddx.textMuted)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Step 2 of "New Nexus": what the Nexus is called, its memo and colour, and
/// whether it gets App Docs. Pops a [NewNexusRequest], or nothing on Cancel.
class NewNexusForm extends ConsumerStatefulWidget {
  final String template;
  final List<String> taken;
  final String defaultName;
  const NewNexusForm({super.key, required this.template, required this.taken, required this.defaultName});

  @override
  ConsumerState<NewNexusForm> createState() => _NewNexusFormState();
}

class _NewNexusFormState extends ConsumerState<NewNexusForm> {
  late final TextEditingController _name = TextEditingController(text: widget.defaultName)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.defaultName.length);
  final _memo = TextEditingController();
  int? _colorId;
  // App Docs by default only for someone's first Nexus (UX-LAYOUT §14.2)
  late bool _appDocs = widget.taken.isEmpty;

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  String? _error(AppLocalizations l) {
    final n = _name.text.trim().toLowerCase();
    return widget.taken.any((t) => t.trim().toLowerCase() == n) ? l.nexusNameTaken : null;
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty || _error(l) != null) return;
    final memo = _memo.text.trim();
    Navigator.pop<NewNexusRequest>(context, (name: name, memo: memo.isEmpty ? null : memo, colorId: _colorId, appDocs: _appDocs));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final error = _error(l);
    final colors = ref.watch(colorsProvider).valueOrNull ?? const <ColorModel>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.newNexusTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(widget.template, style: TextStyle(color: context.ddx.textMuted)),
            const SizedBox(height: 16),
            DdxField(
              key: const ValueKey('new-nexus-name'),
              controller: _name,
              autofocus: true,
              label: '${l.labelName} *',
              errorText: error,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DdxField(controller: _memo, label: l.labelMemo, maxLines: 2),
            const SizedBox(height: 12),
            Text(l.labelColor, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Swatch(code: null, selected: _colorId == null, onTap: () => setState(() => _colorId = null)),
              for (final c in colors)
                _Swatch(code: c.colorCode, selected: _colorId == c.id, onTap: () => setState(() => _colorId = c.id)),
            ]),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('new-nexus-appdocs'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _appDocs,
              onChanged: (v) => setState(() => _appDocs = v ?? false),
              title: Text(l.nexusCreateAppDocs),
              subtitle: Text(l.nexusCreateAppDocsHint),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.btnCancel)),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _name.text.trim().isEmpty || error != null ? null : _submit,
                child: Text(l.btnCreateNexus),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String? code;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.code, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.ddx.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: code ?? 'none',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? p.accent : p.border, width: selected ? 3 : 1),
          ),
          alignment: Alignment.center,
          child: code == null ? Icon(Icons.block, size: 16, color: p.t2) : ColorDot(colorCode: code, size: 22),
        ),
      ),
    );
  }
}

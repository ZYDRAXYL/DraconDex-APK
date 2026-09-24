import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/app_localizations.dart';
import '../data/dao/module_dao.dart';
import '../data/models/module_model.dart';
import '../data/models/recent_view_model.dart';
import '../data/services/entity_location.dart';
import '../data/services/wiki_service.dart';
import '../providers/db_providers.dart';
import '../providers/navigation_providers.dart';

/// Markdown as the desktop writes it (mdRender, EXE renderer/markdown.js), at
/// the size a phone page needs: headings (#, ##, ###), bullet and numbered
/// lists, block quotes, **bold**, *italic*, `code` — and `[[wiki links]]`
/// (APP docs/APK-V3.md §6). A resolved link opens its page; an unresolved
/// one is drawn dimmed and offers to make a Drafter with that name, the
/// desktop's same offer.
class MarkdownView extends ConsumerWidget {
  final String text;
  final int nexusId;
  final TextStyle? style;

  const MarkdownView({super.key, required this.text, required this.nexusId, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium!;
    final blocks = <Widget>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
      } else if (h != null) {
        final level = h.group(1)!.length;
        final hs = [theme.textTheme.titleLarge, theme.textTheme.titleMedium, theme.textTheme.titleSmall][level - 1];
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: _rich(context, ref, h.group(2)!, hs!.copyWith(fontWeight: FontWeight.w600)),
        ));
      } else if (bullet != null || numbered != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(bullet != null ? '•' : '${numbered!.group(1)}.', style: base)),
              Expanded(child: _rich(context, ref, bullet?.group(1) ?? numbered!.group(2)!, base)),
            ],
          ),
        ));
      } else if (quote != null) {
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.dividerColor, width: 3))),
          child: _rich(context, ref, quote.group(1)!, base.copyWith(fontStyle: FontStyle.italic)),
        ));
      } else {
        blocks.add(Padding(padding: const EdgeInsets.only(bottom: 2), child: _rich(context, ref, line, base)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
  }

  Widget _rich(BuildContext context, WidgetRef ref, String line, TextStyle style) =>
      Text.rich(TextSpan(style: style, children: inlineSpans(context, ref, line, style)));

  static final _inlineRe = RegExp(r'\[\[([^\[\]|]+?)(?:\|([^\[\]]+?))?\]\]|\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`');

  List<InlineSpan> inlineSpans(BuildContext context, WidgetRef ref, String line, TextStyle style) {
    final scheme = Theme.of(context).colorScheme;
    final index = ref.watch(nexusIndexProvider(nexusId)).valueOrNull;
    final names = {for (final it in index ?? const []) it.name.toLowerCase()};
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _inlineRe.allMatches(line)) {
      if (m.start > at) out.add(TextSpan(text: line.substring(at, m.start)));
      if (m.group(1) != null) {
        final link = WikiLinkMatch(m.start, m.end, m.group(1)!.trim(), m.group(2)?.trim());
        // Known from the index when it has loaded; an unknown name is only
        // dimmed once the index says so, so nothing flickers while it loads.
        final known = index == null || names.contains(link.label.toLowerCase()) || link.name.contains(':');
        out.add(TextSpan(
          text: link.label,
          style: TextStyle(
            color: known ? scheme.primary : scheme.primary.withValues(alpha: 0.5),
            decoration: TextDecoration.underline,
            decorationStyle: known ? TextDecorationStyle.solid : TextDecorationStyle.dashed,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => openWikiLink(context, ref, link.name, nexusId),
        ));
      } else if (m.group(3) != null) {
        out.add(TextSpan(text: m.group(3), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(4) != null) {
        out.add(TextSpan(text: m.group(4), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        out.add(TextSpan(
          text: m.group(5),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: scheme.surfaceContainerHighest),
        ));
      }
      at = m.end;
    }
    if (at < line.length) out.add(TextSpan(text: line.substring(at)));
    return out;
  }
}

/// Opens what `[[name]]` names, or offers to create a Drafter called that.
Future<void> openWikiLink(BuildContext context, WidgetRef ref, String name, int nexusId) async {
  final router = GoRouter.of(context);
  final l10n = AppLocalizations.of(context)!;
  final db = await ref.read(databaseProvider.future);
  final key = await WikiService.resolveName(db, name, nexusId);
  final location = key == null ? null : await EntityLocation.of(db, key);
  if (location != null) {
    router.push(location);
    return;
  }
  if (!context.mounted) return;
  final label = name.replaceFirst(RegExp(r'^\w+:'), '');
  final create = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: Text(l10n.wikiUnresolved),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.wikiCreateDrafter)),
      ],
    ),
  );
  if (create != true) return;
  final id = await ModuleDao(db).createModule(nexusRef: nexusId, name: label, kind: ModuleKind.drafter);
  ref.invalidate(nexusIndexProvider(nexusId));
  router.push(RecentView.locationFor(nexusId, id));
}

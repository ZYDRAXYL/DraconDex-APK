import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/links/safe_launch.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/models/viewer_model.dart';
import '../../widgets/markdown_view.dart';
import 'block_style.dart';
import 'views/view_common.dart';

/// Page links on the phone — the port of EXE renderer/page/links.js (APP
/// docs/TEMPLATES.md §7.2). Every wiki component keeps its links in one
/// shape, in config.opts:
///   { to: 'module:12' | 'item:cobj_3' | 'item:cobj_3#bio' | 'anchor:bio'
///         | 'url:https://…' | 'wiki:Name', label, icon, group }
/// `wiki:Name` is a [[Name]] that named nothing when it was typed: it
/// resolves by name each time it is drawn, so making the page later mends
/// the link. A web link opens through [safeLaunch] — http(s) only, checked
/// when it is saved and again when it is opened.
final linkToRe = RegExp(r'^(module:\d+|item:[a-z]+_\d+(#[a-z0-9-]{1,40})?|anchor:[a-z0-9-]{1,40}|url:https?://\S+|wiki:[^\n]{1,120})$');

class PageLink {
  final String to, label, icon, group;
  const PageLink(this.to, {this.label = '', this.icon = '', this.group = ''});

  static PageLink? fromJson(Object? o) {
    if (o is! Map || !linkToRe.hasMatch('${o['to'] ?? ''}')) return null;
    String s(Object? v) => v is String ? v : '';
    return PageLink('${o['to']}', label: s(o['label']), icon: s(o['icon']), group: s(o['group']));
  }

  Map<String, Object?> toJson() =>
      {'to': to, if (label.isNotEmpty) 'label': label, if (icon.isNotEmpty) 'icon': icon, if (group.isNotEmpty) 'group': group};

  PageLink copyWith({String? to, String? label, String? group}) =>
      PageLink(to ?? this.to, label: label ?? this.label, icon: icon, group: group ?? this.group);
}

/// The links an option holds; a `to` in none of the shapes is dropped (a
/// newer template's kind, a hand-edited row).
List<PageLink> linksFrom(Object? v) => [for (final o in (v is List ? v : const []).take(60)) ?PageLink.fromJson(o)];

enum LinkKind { module, item, anchor, url, bad }

class ResolvedLink {
  final LinkKind kind;
  final String name;
  final String? key, anchor, host, want;
  final int? moduleId;
  final bool dangling;
  const ResolvedLink(this.kind, {this.name = '', this.key, this.anchor, this.host, this.want, this.moduleId, this.dangling = false});
}

IndexedItem? _byName(List<IndexedItem> index, String name) {
  final n = name.trim().toLowerCase();
  // a module first, as the desktop's name index prefers it
  return index.where((e) => e.itemKind == 'module' && e.name.toLowerCase() == n).firstOrNull ??
      index.where((e) => e.name.toLowerCase() == n).firstOrNull;
}

/// What a link points at, by the Nexus index. With no [index] yet (first
/// paint) nothing counts as gone: only a loaded index can say so.
ResolvedLink resolveLink(PageLink l, List<IndexedItem>? index) {
  final to = l.to;
  RegExpMatch? m;
  if ((m = RegExp(r'^wiki:(.+)$').firstMatch(to)) != null) {
    final e = index == null ? null : _byName(index, m![1]!);
    if (e == null) return ResolvedLink(LinkKind.item, name: m![1]!, want: m[1], dangling: index != null);
    return resolveLink(PageLink(e.itemKind == 'module' ? 'module:${e.moduleId}' : 'item:${e.key}'), index);
  }
  if ((m = RegExp(r'^module:(\d+)$').firstMatch(to)) != null) {
    final id = int.parse(m![1]!);
    final e = index?.where((x) => x.key == 'module_$id').firstOrNull;
    return ResolvedLink(LinkKind.module, moduleId: id, key: 'module_$id', name: e?.name ?? '', dangling: index != null && e == null);
  }
  if ((m = RegExp(r'^item:([a-z]+_\d+)(?:#([a-z0-9-]+))?$').firstMatch(to)) != null) {
    final e = index?.where((x) => x.key == m![1]).firstOrNull;
    return ResolvedLink(LinkKind.item, key: m![1], anchor: m[2], name: e?.name ?? '', moduleId: e?.moduleId, dangling: index != null && e == null);
  }
  if ((m = RegExp(r'^anchor:([a-z0-9-]+)$').firstMatch(to)) != null) return ResolvedLink(LinkKind.anchor, anchor: m![1]);
  if (to.startsWith('url:') && isSafeWebUrl(to.substring(4))) {
    return ResolvedLink(LinkKind.url, host: Uri.parse(to.substring(4)).host.replaceFirst(RegExp(r'^www\.'), ''));
  }
  return const ResolvedLink(LinkKind.bad, dangling: true);
}

/// The words a link shows: its label (a [[wikilink]] in it read as its
/// text), else what it points at.
String linkLabel(PageLink l, ResolvedLink r) {
  final label = l.label.replaceAllMapped(RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'), (m) => m[2] ?? m[1]!).trim();
  if (label.isNotEmpty) return label;
  if (r.name.isNotEmpty) return r.name;
  if (r.host != null) return r.host!;
  if (r.anchor != null) return '#${r.anchor}';
  return '—';
}

/// What the user typed — [[Name]], #anchor, https://… or a bare name — as a
/// `to`, or null when it is not a link at all (file:, javascript:, data: …).
String? parseLinkInput(String raw, List<IndexedItem>? index) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  RegExpMatch? m;
  if ((m = RegExp(r'^#([A-Za-z0-9 _-]{1,40})$').firstMatch(s)) != null) return 'anchor:${BlockStyle.cleanAnchor(m![1])}';
  if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(s) && !RegExp(r'^(module|item|anchor|wiki):').hasMatch(s)) {
    return isSafeWebUrl(s) ? 'url:${Uri.parse(s)}' : null;
  }
  if ((m = RegExp(r'^\[\[([^\]|#]+)(?:\|[^\]]*)?\]\](?:#([A-Za-z0-9_-]{1,40}))?$').firstMatch(s)) != null ||
      (m = RegExp(r'^([^\[\]#:]{1,120})$').firstMatch(s)) != null) {
    final name = m![1]!.trim();
    final e = index == null ? null : _byName(index, name);
    if (e == null) return 'wiki:$name';
    if (e.itemKind == 'module') return 'module:${e.moduleId}';
    final a = m.groupCount >= 2 && m[2] != null ? '#${BlockStyle.cleanAnchor(m[2])}' : '';
    return 'item:${e.key}$a';
  }
  return linkToRe.hasMatch(s) ? s : null;
}

/// A link the way it is typed back into the editor.
String linkInputOf(PageLink l, ResolvedLink r) {
  if (l.to.startsWith('wiki:')) return '[[${l.to.substring(5)}]]';
  if (r.kind == LinkKind.anchor) return '#${r.anchor}';
  if (r.kind == LinkKind.url) return l.to.substring(4);
  if (r.kind == LinkKind.module || r.kind == LinkKind.item) {
    return '[[${r.name.isNotEmpty ? r.name : (r.key ?? '')}]]${r.anchor != null ? '#${r.anchor}' : ''}';
  }
  return l.to;
}

// ── anchors on the open page ────────────────────────────────────────────
/// Where each block with an anchor sits, so an `anchor:` link (a linkbar,
/// a contents list) can scroll to it. A block registers while it is on
/// screen; the first one still mounted wins.
class PageAnchors {
  static final Map<String, List<BuildContext>> _marks = {};

  static void _add(String anchor, BuildContext c) => (_marks[anchor] ??= []).add(c);
  static void _remove(String anchor, BuildContext c) => _marks[anchor]?.remove(c);

  /// → false when no block on screen has that anchor.
  static bool scrollTo(String anchor) {
    final c = _marks[BlockStyle.cleanAnchor(anchor)]?.where((c) => c.mounted).firstOrNull;
    if (c == null) return false;
    Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignment: .05);
    return true;
  }
}

/// Marks a block with its anchor — its own, or `b<id>` as on the desktop.
class AnchorMark extends StatefulWidget {
  final String anchor;
  final Widget child;
  const AnchorMark({super.key, required this.anchor, required this.child});

  @override
  State<AnchorMark> createState() => _AnchorMarkState();
}

class _AnchorMarkState extends State<AnchorMark> {
  @override
  void initState() {
    super.initState();
    PageAnchors._add(widget.anchor, context);
  }

  @override
  void didUpdateWidget(AnchorMark old) {
    super.didUpdateWidget(old);
    if (old.anchor != widget.anchor) {
      PageAnchors._remove(old.anchor, context);
      PageAnchors._add(widget.anchor, context);
    }
  }

  @override
  void dispose() {
    PageAnchors._remove(widget.anchor, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── follow ──────────────────────────────────────────────────────────────
Future<void> followLink(BuildContext context, WidgetRef ref, PageLink l, ResolvedLink r, int nexusId) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  switch (r.kind) {
    case LinkKind.anchor:
      if (!PageAnchors.scrollTo(r.anchor!)) messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkMissing)));
    case LinkKind.url:
      if (!await safeLaunch(l.to.substring(4))) messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkBadUrl)));
    case LinkKind.bad:
      messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkMissing)));
    case LinkKind.module:
      if (r.dangling) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkMissing)));
      } else {
        GoRouter.of(context).push(RecentView.locationFor(nexusId, r.moduleId!));
      }
    case LinkKind.item:
      // a name that names nothing yet offers to make it — a [[wikilink]]'s rule
      if (r.want != null && r.dangling) {
        await openWikiLink(context, ref, r.want!, nexusId);
      } else if (r.dangling) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.pbLinkMissing)));
      } else {
        await openKey(context, ref, r.key!);
      }
  }
}

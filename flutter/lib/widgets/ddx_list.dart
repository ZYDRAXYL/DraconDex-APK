import 'package:flutter/material.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart';
import 'grouped_section.dart';
import 'row_menu.dart';

/// The one list of the app (Procress 21, APP docs/UX-LAYOUT.md §12): every
/// list row, group, list header and empty state is built here, so a list
/// learnt on one page reads the same on every other.
///
/// - [DdxListTile] — a row, in one of the two densities
/// - [DdxListSection] — a group: sticky header, count, folds
/// - [DdxListHeader] — filter · sort · total count, in the same spot everywhere
/// - [DdxEmptyState] — icon + one sentence + at most one button
///
/// Every size is a token from tokens.g.dart (vendored from DraconDex-SDB).
/// Everything works inside a `ListView.builder` or as slivers, so a long list
/// still builds only the rows on screen (Procress 19 F5, §12.8).

/// The two row heights (§12.2) — nothing else.
enum DdxDensity {
  /// 28: the tree, menus, lists inside a panel.
  compact,

  /// 40: a list that is the page (Trash, Problems, Assets, Search, Settings).
  comfortable,
}

/// A row's height at [density], times the text scale (the app's UI Size
/// setting is a text scaler, app.dart) — §12.2 lets both scale, never mix.
double ddxRowHeight(BuildContext context, DdxDensity density) => MediaQuery.textScalerOf(context)
    .scale(density == DdxDensity.compact ? DdxSize.rowCompact : DdxSize.rowComfy);

/// The selected row's left bar (§12.3): selection is never colour alone.
const double _selectedBar = 3;

/// One row (§12.1): leading icon · title (one line, …) · meta · trailing
/// (count/badge, then actions, then ⋯).
///
/// Comfortable rows put [meta] on a second line; compact rows put it at the
/// end, before the count. Given [actions], the row carries its ⋯ — always
/// shown, this is a touch screen (§12.1) — and a long press opens the same
/// menu unless [onLongPress] says otherwise.
class DdxListTile extends StatelessWidget {
  const DdxListTile({
    super.key,
    required this.title,
    this.leading,
    this.icon,
    this.meta,
    this.metaMaxLines = 1,
    this.count,
    this.trailing = const [],
    this.actions,
    this.menuTitle,
    this.density = DdxDensity.comfortable,
    this.selected = false,
    this.enabled = true,
    this.indent = 0,
    this.reorderIndex,
    this.onTap,
    this.onLongPress,
  });

  final String title;

  /// Any leading widget (a colour dot, a thumbnail, an icon square). Wins
  /// over [icon].
  final Widget? leading;

  /// The usual leading: an icon at `DdxSize.iconSm`.
  final IconData? icon;

  /// The secondary text, in the muted colour that still reaches 4.5:1.
  final String? meta;

  /// A sentence the reader must see whole (a note under a setting) may take
  /// more than one line; a row of data never does.
  final int metaMaxLines;

  /// A count or a badge — always visible.
  final String? count;

  /// Row actions shown as buttons, before the ⋯.
  final List<Widget> trailing;

  /// The row's menu (opened by ⋯ and by a long press), ordered by
  /// [showRowMenu]'s rules (§12.6: delete last).
  final List<RowAction> Function()? actions;

  /// The menu's title; the row's [title] when null.
  final String? menuTitle;

  final DdxDensity density;
  final bool selected;
  final bool enabled;

  /// Extra start padding — a tree's depth.
  final double indent;

  /// In a reorderable list: the row's index, and the drag handle goes first,
  /// in the same spot on every list that can be reordered (§12 part 3).
  final int? reorderIndex;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final compact = density == DdxDensity.compact;
    final metaStyle = TextStyle(fontSize: DdxFontSize.fsSm, height: DdxLineHeight.lhSnug, color: ddx.textMuted);

    Widget titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: DdxFontSize.fsBody,
        height: DdxLineHeight.lhSnug,
        color: enabled ? null : ddx.textMuted,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
    );
    // The meta rides inside the title box rather than as ListTile's
    // subtitle: a subtitle switches ListTile to its own two-line heights,
    // and a row here is 28 or 40, nothing else.
    if (!compact && meta != null && meta!.isNotEmpty) {
      titleWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleWidget, Text(meta!, maxLines: metaMaxLines, overflow: TextOverflow.ellipsis, style: metaStyle)],
      );
    }

    Widget? lead = leading ?? (icon == null ? null : Icon(icon, size: DdxSize.iconSm));
    if (reorderIndex != null) {
      lead = Row(mainAxisSize: MainAxisSize.min, children: [
        ReorderableDragStartListener(
          index: reorderIndex!,
          child: Icon(Icons.menu, size: DdxSize.iconMd, color: ddx.textMuted),
        ),
        if (lead != null) ...[const SizedBox(width: DdxSpace.sp3), lead],
      ]);
    }

    final tail = <Widget>[
      if (compact && meta != null && meta!.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DdxSize.modalSm / 4),
          child: Text(meta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle),
        ),
      if (count != null) Text(count!, style: metaStyle),
      ...trailing,
      if (actions != null)
        RowMenuButton(
          actions: actions!,
          title: menuTitle ?? title,
          dense: compact,
          iconSize: compact ? DdxSize.iconSm : DdxSize.iconMd,
        ),
    ];

    final longPress = onLongPress ??
        (actions == null || !enabled ? null : () => showRowMenu(context, actions!(), title: menuTitle ?? title));

    final tile = ListTile(
      enabled: enabled,
      selected: selected,
      dense: compact,
      visualDensity: VisualDensity.standard,
      minTileHeight: ddxRowHeight(context, density),
      minVerticalPadding: DdxSpace.sp0,
      minLeadingWidth: DdxSize.iconSm,
      horizontalTitleGap: compact ? DdxSpace.sp3 : DdxSpace.sp5,
      contentPadding: EdgeInsetsDirectional.only(
        start: (compact ? DdxSpace.sp3 : DdxSpace.sp7) + indent,
        end: compact ? DdxSpace.sp1 : DdxSpace.sp3,
      ),
      leading: lead,
      title: titleWidget,
      trailing: tail.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, spacing: DdxSpace.sp1, children: tail),
      onTap: onTap,
      onLongPress: longPress,
    );
    if (!selected) return tile;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: ddx.palette.accent, width: _selectedBar)),
      ),
      child: tile,
    );
  }
}

/// A group of rows (§12.4): a header with the group's name and how many it
/// holds, folding on a tap — sticky over its rows when used as a sliver.
///
/// On iPhone/iPad it is the grouped inset card ([DdxGroupedSection]) with the
/// count and the chevron on its caption. Whether a group is folded is kept per
/// list for as long as the page lives ([PageStorage], keyed by [storageId] or
/// the title).
class DdxListSection extends StatefulWidget {
  /// A short group, built at once (a settings section).
  const DdxListSection({
    super.key,
    required this.title,
    this.count,
    required List<Widget> this.children,
    this.collapsible = true,
    this.initiallyCollapsed = false,
    this.storageId,
    this.separatorIndent = 16,
  })  : itemCount = null,
        itemBuilder = null;

  /// A long group as a sliver: its rows are built as they scroll in and its
  /// header stays pinned while they pass under it.
  const DdxListSection.sliver({
    super.key,
    required this.title,
    this.count,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.collapsible = true,
    this.initiallyCollapsed = false,
    this.storageId,
    this.separatorIndent = 16,
  }) : children = null;

  final String title;

  /// How many the group holds; null hides the count (a settings section).
  final int? count;

  final bool collapsible;
  final bool initiallyCollapsed;
  final String? storageId;

  /// iOS: where the separators start — past the icon square when rows have one.
  final double separatorIndent;

  /// The rows of a box section; null for a sliver.
  final List<Widget>? children;

  /// The rows of a sliver section; null for a box.
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;

  bool get isSliver => itemBuilder != null;

  @override
  State<DdxListSection> createState() => _DdxListSectionState();
}

class _DdxListSectionState extends State<DdxListSection> {
  bool? _collapsed;

  String get _storageId => 'ddx-section:${widget.storageId ?? widget.title}';

  bool get _open => !(_collapsed ?? widget.initiallyCollapsed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_collapsed == null && widget.collapsible) {
      final kept = PageStorage.maybeOf(context)?.readState(context, identifier: _storageId);
      _collapsed = kept is bool ? kept : widget.initiallyCollapsed;
    }
  }

  void _toggle() {
    setState(() => _collapsed = _open);
    PageStorage.maybeOf(context)?.writeState(context, _collapsed, identifier: _storageId);
  }

  /// The count, then the chevron.
  Widget? _tail(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final muted = context.ddx.textMuted;
    final count = widget.count;
    if (count == null && !widget.collapsible) return null;
    return Row(mainAxisSize: MainAxisSize.min, spacing: DdxSpace.sp1, children: [
      if (count != null)
        Semantics(
          label: l.listCount.replaceAll('{n}', '$count'),
          excludeSemantics: true,
          child: Text('$count', style: TextStyle(fontSize: DdxFontSize.fsSm, color: muted)),
        ),
      if (widget.collapsible) Icon(_open ? Icons.expand_more : Icons.chevron_right, size: DdxSize.iconMd, color: muted),
    ]);
  }

  /// The Material header: the name in the accent, then the count and chevron.
  Widget _header(BuildContext context, {required bool pinned}) {
    final theme = Theme.of(context);
    final tail = _tail(context);
    Widget line = ConstrainedBox(
      constraints: BoxConstraints(minHeight: ddxRowHeight(context, DdxDensity.comfortable)),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: DdxSpace.sp7, end: DdxSpace.sp5),
        child: Row(children: [
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: DdxFontSize.fsSm, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
            ),
          ),
          ?tail,
        ]),
      ),
    );
    if (widget.collapsible) line = InkWell(onTap: _toggle, child: line);
    return Semantics(
      container: true,
      header: true,
      button: widget.collapsible,
      expanded: widget.collapsible ? _open : null,
      child: Material(
        // pinned, the rows scroll under it — it needs a floor of its own
        color: pinned ? theme.scaffoldBackgroundColor : Colors.transparent,
        child: line,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ios = context.isIosStyle;
    final open = _open || !widget.collapsible;
    final onTap = widget.collapsible ? _toggle : null;

    if (!widget.isSliver) {
      final rows = open ? widget.children! : const <Widget>[];
      if (ios) {
        return Semantics(
          expanded: widget.collapsible ? open : null,
          child: DdxGroupedSection(
            header: widget.title,
            headerTrailing: _tail(context),
            onHeaderTap: onTap,
            separatorIndent: widget.separatorIndent,
            children: rows,
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_header(context, pinned: false), ...rows],
      );
    }

    final count = open ? widget.itemCount! : 0;
    if (ios) {
      return SliverMainAxisGroup(slivers: [
        PinnedHeaderSliver(
          child: Semantics(
            container: true,
            header: true,
            button: widget.collapsible,
            expanded: widget.collapsible ? open : null,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, DdxSpace.sp3, 16, 0),
                child: DdxGroupedSection.caption(context, widget.title, trailing: _tail(context), onTap: onTap),
              ),
            ),
          ),
        ),
        DdxGroupedSection.sliver(
          itemCount: count,
          itemBuilder: widget.itemBuilder!,
          separatorIndent: widget.separatorIndent,
        ),
      ]);
    }
    return SliverMainAxisGroup(slivers: [
      PinnedHeaderSliver(child: _header(context, pinned: true)),
      SliverList.builder(itemCount: count, itemBuilder: widget.itemBuilder!),
    ]);
  }
}

/// How a list can be ordered (§12.4) — the same four words on every list.
enum DdxSort { name, edited, created, kind }

/// [sort]'s label; null is the list's own order ("As arranged").
String ddxSortLabel(AppLocalizations l, DdxSort? sort) => switch (sort) {
      null => l.listSortManual,
      DdxSort.name => l.listSortName,
      DdxSort.edited => l.listSortEdited,
      DdxSort.created => l.listSortCreated,
      DdxSort.kind => l.listSortKind,
    };

/// [items] in [sort]'s order: names A→Z, dates newest first, kinds A→Z then
/// by name; null keeps [items]' own order. Stable — ties keep that order.
/// A key the list has no getter for leaves the order as it was.
List<T> ddxSorted<T>(
  Iterable<T> items,
  DdxSort? sort, {
  required String Function(T) name,
  String Function(T)? edited,
  String Function(T)? created,
  String Function(T)? kind,
}) {
  final list = items.toList();
  int byName(T a, T b) => name(a).toLowerCase().compareTo(name(b).toLowerCase());
  final int Function(T, T)? cmp = switch (sort) {
    null => null,
    DdxSort.name => byName,
    DdxSort.edited => edited == null ? null : (a, b) => edited(b).compareTo(edited(a)),
    DdxSort.created => created == null ? null : (a, b) => created(b).compareTo(created(a)),
    DdxSort.kind => kind == null
        ? null
        : (a, b) {
            final k = kind(a).toLowerCase().compareTo(kind(b).toLowerCase());
            return k != 0 ? k : byName(a, b);
          },
  };
  if (cmp == null) return list;
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = cmp(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Whether any of [fields] contains [query], ignoring case. An empty query
/// matches everything.
bool ddxMatches(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}

/// The time groups of a list ordered by when (§12.4: Trash, history).
enum DdxDateGroup { today, thisWeek, older }

/// Which group [when] falls in, seen from [now]. The week starts on
/// [firstDayOfWeekIndex] — 0 is Sunday, as [MaterialLocalizations] counts.
/// A time in the future (a clock that moved) counts as today.
DdxDateGroup ddxDateGroup(DateTime when, DateTime now, {int firstDayOfWeekIndex = 1}) {
  final today = DateTime(now.year, now.month, now.day);
  final w = when.toLocal();
  if (!w.isBefore(today)) return DdxDateGroup.today;
  final sinceWeekStart = (now.weekday % 7 - firstDayOfWeekIndex) % 7;
  final weekStart = DateTime(now.year, now.month, now.day - sinceWeekStart);
  return w.isBefore(weekStart) ? DdxDateGroup.older : DdxDateGroup.thisWeek;
}

String ddxDateGroupLabel(AppLocalizations l, DdxDateGroup g) => switch (g) {
      DdxDateGroup.today => l.listGroupToday,
      DdxDateGroup.thisWeek => l.listGroupThisWeek,
      DdxDateGroup.older => l.listGroupOlder,
    };

/// A database time (`datetime('now')`: UTC, "YYYY-MM-DD HH:MM:SS"), in local
/// time; null when it does not parse.
DateTime? ddxParseDbTime(String s) {
  if (s.isEmpty) return null;
  final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  final zoned = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(iso) ? iso : '${iso}Z';
  return DateTime.tryParse(zoned)?.toLocal();
}

/// The top of a list that can grow long (§12.4): a filter field, the sort,
/// and the total — in that order, in this place, on every list. A list
/// without a filter shows [title] where the field would be; [trailing]
/// (a view-mode button) goes last.
class DdxListHeader extends StatefulWidget {
  const DdxListHeader({
    super.key,
    required this.count,
    this.onFilterChanged,
    this.sort,
    this.sorts = const [],
    this.onSortChanged,
    this.manualOrder = false,
    this.title,
    this.trailing = const [],
  });

  /// How many rows the list shows now.
  final int count;

  /// Given, the filter field shows and reports every change.
  final ValueChanged<String>? onFilterChanged;

  /// The current order; null is the list's own ([manualOrder]).
  final DdxSort? sort;

  /// The orders this list offers — the ones its rows have data for.
  final List<DdxSort> sorts;
  final ValueChanged<DdxSort?>? onSortChanged;

  /// The list has an order of its own (arranged by hand) to go back to.
  final bool manualOrder;

  final String? title;
  final List<Widget> trailing;

  @override
  State<DdxListHeader> createState() => _DdxListHeaderState();
}

class _DdxListHeaderState extends State<DdxListHeader> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    widget.onFilterChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = context.ddx.textMuted;
    final metaStyle = TextStyle(fontSize: DdxFontSize.fsSm, color: muted);
    final scale = MediaQuery.textScalerOf(context);

    final Widget lead;
    if (widget.onFilterChanged != null) {
      lead = SizedBox(
        height: scale.scale(DdxSize.ctlMd),
        child: TextField(
          controller: _filter,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: DdxFontSize.fsBody),
          decoration: InputDecoration(
            isDense: true,
            hintText: l.listFilterHint,
            contentPadding: const EdgeInsets.symmetric(horizontal: DdxSpace.sp3, vertical: DdxSpace.sp2),
            prefixIcon: const Icon(Icons.filter_list, size: DdxSize.iconSm),
            prefixIconConstraints: const BoxConstraints(minWidth: DdxSize.ctlMd),
            suffixIcon: _filter.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: DdxSize.iconSm),
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _filter.clear();
                      _changed('');
                    },
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(DdxRadius.r)),
          ),
        ),
      );
    } else {
      lead = Text(widget.title ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(color: muted));
    }

    final canSort = widget.onSortChanged != null && widget.sorts.isNotEmpty;
    final options = <DdxSort?>[if (widget.manualOrder) null, ...widget.sorts];
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: ddxRowHeight(context, DdxDensity.comfortable)),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: DdxSpace.sp7, end: DdxSpace.sp3),
        child: Row(spacing: DdxSpace.sp3, children: [
          Expanded(child: lead),
          if (canSort)
            PopupMenuButton<int>(
              key: const ValueKey('ddx-list-sort'),
              tooltip: '${l.listSort}: ${ddxSortLabel(l, widget.sort)}',
              // an index into options: a null (as arranged) is a value too
              onSelected: (i) => widget.onSortChanged!(options[i]),
              itemBuilder: (_) => [
                for (var i = 0; i < options.length; i++)
                  CheckedPopupMenuItem<int>(
                    value: i,
                    checked: options[i] == widget.sort,
                    child: Text(ddxSortLabel(l, options[i])),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DdxSpace.sp2),
                child: Row(mainAxisSize: MainAxisSize.min, spacing: DdxSpace.sp1, children: [
                  Icon(Icons.sort, size: DdxSize.iconSm, color: muted),
                  Text(ddxSortLabel(l, widget.sort), style: metaStyle),
                ]),
              ),
            ),
          Semantics(
            label: l.listCount.replaceAll('{n}', '${widget.count}'),
            excludeSemantics: true,
            child: Text('${widget.count}', style: metaStyle),
          ),
          ...widget.trailing,
        ]),
      ),
    );
  }
}

/// An empty list or page (§12.5): an icon, ONE sentence saying what goes
/// here, and at most one primary button — the API has room for no second.
/// [title] names the place when the page has nothing else to name it
/// (a module's empty page); [note] is that page's state line, which the
/// component contract (APP docs/redesign/COMPONENTS.md) keeps under the
/// kind's sentence — nothing else passes one.
class DdxEmptyState extends StatelessWidget {
  const DdxEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.note,
    this.iconColor,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? title;
  final String? note;
  final Color? iconColor;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ddx = context.ddx;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DdxSize.modalSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DdxSpace.sp7 + DdxSpace.sp3, vertical: DdxSpace.sp7 * 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: DdxSize.iconMd, color: iconColor ?? ddx.textMuted),
              const SizedBox(height: DdxSpace.sp4),
              if (title != null) ...[
                Text(title!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: DdxSpace.sp1),
              ],
              Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: ddx.textMuted)),
              if (note != null) ...[
                const SizedBox(height: DdxSpace.sp2),
                Text(note!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: ddx.textMuted)),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: DdxSpace.sp7),
                FilledButton.icon(onPressed: onAction, icon: Icon(actionIcon, size: DdxSize.iconSm), label: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

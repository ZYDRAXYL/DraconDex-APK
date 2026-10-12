import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart';

/// A grouped inset list — the Apple Settings look (APP docs/REDESIGN.md C3):
/// rows on one rounded card, hairline separators that start past the icon,
/// an optional uppercase caption above. iOS only; callers keep their plain
/// Material list elsewhere.
///
/// [DdxListSection] (widgets/ddx_list.dart) builds its iOS look on this card:
/// [headerTrailing] carries the group's count and chevron, [onHeaderTap]
/// folds it.
class DdxGroupedSection extends StatelessWidget {
  const DdxGroupedSection({
    super.key,
    this.header,
    required this.children,
    this.separatorIndent = 16,
    this.headerTrailing,
    this.onHeaderTap,
  });

  final String? header;
  final List<Widget> children;

  /// Drawn at the caption's end — a count, a chevron.
  final Widget? headerTrailing;

  /// Makes the caption a button (folding the section).
  final VoidCallback? onHeaderTap;

  /// Where the separator starts — past the icon square for rows that have one.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: separatorIndent),
          child: Container(height: DdxIos.sizeSeparatorWidth, color: ddx.iosSeparator),
        ));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) caption(context, header!, trailing: headerTrailing, onTap: onHeaderTap),
          ClipRRect(
            borderRadius: BorderRadius.circular(DdxIos.radiusGroup),
            child: Material(color: ddx.palette.surface, child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
          ),
        ],
      ),
    );
  }

  /// The uppercase caption above a card, with [trailing] at its end and,
  /// given [onTap], the whole line a button.
  static Widget caption(BuildContext context, String header, {Widget? trailing, VoidCallback? onTap}) {
    final text = Text(header.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: DdxIos.sizeFootnote, color: context.ddx.textMuted, letterSpacing: 0));
    final line = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: trailing == null ? text : Row(children: [Expanded(child: text), trailing]),
    );
    return onTap == null ? line : InkWell(onTap: onTap, child: line);
  }

  /// The same card as a sliver of [itemCount] rows, built as they scroll in
  /// (Procress 19 F5): each row draws its own slice of the card — the
  /// first rounds the top corners, the last the bottom, every other row
  /// starts with the separator.
  static Widget sliver({
    String? header,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double separatorIndent = 16,
    Widget? headerTrailing,
    VoidCallback? onHeaderTap,
  }) {
    final lead = header == null ? 0 : 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      sliver: SliverList.builder(
        itemCount: itemCount + lead,
        itemBuilder: (context, j) {
          if (j < lead) return caption(context, header!, trailing: headerTrailing, onTap: onHeaderTap);
          final i = j - lead;
          final ddx = context.ddx;
          const r = Radius.circular(DdxIos.radiusGroup);
          return ClipRRect(
            borderRadius: BorderRadius.vertical(top: i == 0 ? r : Radius.zero, bottom: i == itemCount - 1 ? r : Radius.zero),
            child: Material(
              color: ddx.palette.surface,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: separatorIndent),
                    child: Container(height: DdxIos.sizeSeparatorWidth, color: ddx.iosSeparator),
                  ),
                itemBuilder(context, i),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// The coloured square an iOS list row leads with.
class DdxIconSquare extends StatelessWidget {
  const DdxIconSquare({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: DdxIos.sizeIconBox,
        height: DdxIos.sizeIconBox,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(DdxIos.radiusIcon)),
        child: Icon(icon, size: 18, color: Colors.white),
      );
}

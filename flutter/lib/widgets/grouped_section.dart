import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart';

/// A grouped inset list — the Apple Settings look (APP docs/REDESIGN.md C3):
/// rows on one rounded card, hairline separators that start past the icon,
/// an optional uppercase caption above. iOS only; callers keep their plain
/// Material list elsewhere.
class DdxGroupedSection extends StatelessWidget {
  const DdxGroupedSection({super.key, this.header, required this.children, this.separatorIndent = 16});

  final String? header;
  final List<Widget> children;

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
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(header!.toUpperCase(),
                  style: TextStyle(fontSize: DdxIos.sizeFootnote, color: ddx.textMuted, letterSpacing: 0)),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(DdxIos.radiusGroup),
            child: Material(color: ddx.palette.surface, child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
          ),
        ],
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

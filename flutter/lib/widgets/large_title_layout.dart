import 'package:flutter/material.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart';
import 'hiding_app_bar.dart';

/// A screen's app bar and body, with the Apple large title on iOS (APP
/// docs/REDESIGN.md C3): the title sits big under the bar and folds into the
/// bar once the page scrolls. Android keeps its one Material bar, which
/// steps aside while scrolling (HidingAppBar).
///
/// [appBar] is built with `showTitle`: false while the large title is
/// showing on iOS, so the name is never on screen twice.
class LargeTitleLayout extends StatefulWidget {
  const LargeTitleLayout({super.key, required this.title, required this.appBar, required this.body});

  final String title;
  final PreferredSizeWidget Function(bool showTitle) appBar;
  final Widget body;

  @override
  State<LargeTitleLayout> createState() => _LargeTitleLayoutState();
}

class _LargeTitleLayoutState extends State<LargeTitleLayout> {
  bool _folded = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final folded = n.metrics.pixels > 8;
    if (folded != _folded) setState(() => _folded = folded);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isIosStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [HidingAppBar(appBar: widget.appBar(true)), Expanded(child: widget.body)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HidingAppBar(appBar: widget.appBar(_folded)),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _folded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: DdxIos.sizeLargeTitle, fontWeight: FontWeight.w700, height: 1.2)),
                ),
        ),
        Expanded(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.body)),
      ],
    );
  }
}

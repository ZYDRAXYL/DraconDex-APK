import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_providers.dart';

/// An app bar that steps aside while the user scrolls down and comes back on
/// the way up (APK V3 focus, APP docs/APK-V3.md §10.5, §13 item 18) — the
/// phone shell decides when, through [chromeVisibleProvider].
///
/// It sits at the top of the screen's BODY rather than in `Scaffold.appBar`,
/// because a Scaffold lays its app bar out at the height the bar asks for
/// up front and cannot animate it away. Hidden, it leaves the status bar's
/// height behind so the page does not slide under the clock.
class HidingAppBar extends ConsumerWidget {
  final PreferredSizeWidget appBar;

  const HidingAppBar({super.key, required this.appBar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(chromeVisibleProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: visible
          ? appBar
          : SizedBox(width: double.infinity, height: MediaQuery.paddingOf(context).top),
    );
  }
}

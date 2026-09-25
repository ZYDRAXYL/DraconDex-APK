// Which shape the app's shell takes on the surface it is currently running
// on. The Flutter front-end ships to phones, to tablets/iPad (APK/IPA) and to
// the browser (the PWA's mobile lane), and those are not the same screen: a
// phone can only afford one column and a bar of actions along the bottom
// edge, while a tablet has room for the desktop build's shape — a vertical
// nav rail plus a hub panel beside the content (see docs/PWA.md §7).
//
// Deliberately measured from the window, not from the platform: an iPad app
// in Slide Over or a half-width Split View really is a phone-shaped column
// and gets the phone shell, and a browser window narrowed on a desktop does
// the same. Nothing here asks "is this iOS/Android" — only "how much room is
// there right now".

import 'package:flutter/widgets.dart';

/// Minimum width before the shell is willing to spend room on a vertical
/// rail. Matches Material's medium window-size class.
const double kTabletMinWidth = 600;

/// …and the minimum height, which is what keeps a phone held sideways
/// (wide, but only ~400dp tall) on the phone shell where it belongs.
const double kTabletMinHeight = 500;

/// From here on there is room for the rail *and* the hub panel at once, so
/// the panel starts out open — an iPad in landscape, or a desktop browser.
/// 840 is Material's expanded window-size class (APP docs/REDESIGN.md G7;
/// was 1000): rail 76 + panel 288 + the 340 the content keeps = 704, so the
/// three columns still fit with room to spare.
const double kWideMinWidth = 840;

/// Widths of the shell's own chrome (see features/builder/).
const double kRailWidth = 76;
const double kRailExtendedWidth = 208;
const double kHubPanelMinWidth = 220;
const double kHubPanelMaxWidth = 460;
const double kHubPanelDefaultWidth = 288;

/// How much room the content pane must keep for the hub panel to sit beside
/// it. Below this the panel becomes a drawer over the content instead — a
/// half-width Split View has no business being three columns.
const double kMinContentWidth = 340;

enum DdxLayoutClass {
  /// One column, actions on a bottom bar. Phones, and any window narrow or
  /// short enough to be shaped like one.
  phone,

  /// Vertical rail beside the content; the hub panel is available but not
  /// assumed. Tablets in portrait, iPad Split View at two thirds.
  tablet,

  /// Rail, hub panel and content side by side — the Electron shape.
  wide;

  bool get isPhone => this == DdxLayoutClass.phone;

  /// True for every shell that has the vertical rail (tablet and wider).
  bool get hasRail => this != DdxLayoutClass.phone;

  bool get isWide => this == DdxLayoutClass.wide;
}

DdxLayoutClass ddxLayoutForSize(Size size) {
  if (size.width < kTabletMinWidth || size.height < kTabletMinHeight) {
    return DdxLayoutClass.phone;
  }
  return size.width >= kWideMinWidth ? DdxLayoutClass.wide : DdxLayoutClass.tablet;
}

/// The shell shape for the window this widget is in. Uses [MediaQuery.sizeOf]
/// so a rotation, a Split View resize or a dragged browser window rebuilds
/// only the widgets that actually asked about the layout.
DdxLayoutClass ddxLayoutOf(BuildContext context) => ddxLayoutForSize(MediaQuery.sizeOf(context));

/// How wide one tile in a grid collection may get, per layout — the phone's
/// 170 was picked for a 2-3 column phone grid and leaves a tablet looking
/// like a phone screenshot blown up.
double gridTileExtentFor(DdxLayoutClass layout) => switch (layout) {
      DdxLayoutClass.phone => 170,
      DdxLayoutClass.tablet => 190,
      DdxLayoutClass.wide => 210,
    };

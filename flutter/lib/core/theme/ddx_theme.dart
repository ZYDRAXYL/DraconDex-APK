import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Everything the app's widgets need that [ColorScheme] has no slot for —
/// the palette as the desktop names it, muted text that reaches 4.5:1, the
/// radius scale, and the iOS layer's derived colours (APP docs/REDESIGN.md
/// C3, C4, C5). The values come from tokens.g.dart, generated in
/// DraconDex-SDB from the same design/tokens.json EXE's CSS comes from.
///
/// The Glass UI style rides here too (APP Plan.md Procress 23): whether it
/// is on, how it should draw on this device, and its values for the active
/// theme — the same `DdxGlass` tokens EXE's CSS gets.
///
/// Read it with `context.ddx`.
@immutable
class DdxThemeExt extends ThemeExtension<DdxThemeExt> {
  const DdxThemeExt({
    required this.name,
    required this.palette,
    this.radius = 8,
    this.radiusSmall = 4,
    this.radiusLarge = 12,
    this.glass = false,
    this.reduceTransparency = false,
    this.glassBlurOff = false,
  });

  /// The theme's key in [ddxPalettes] (midnight, atDusk, …).
  final String name;
  final DdxPalette palette;
  final double radius;
  final double radiusSmall;
  final double radiusLarge;

  /// The Glass UI style is on: the bars and the floating layers draw as
  /// `DdxGlass` panes (widgets/ddx_glass.dart). Page content never does.
  final bool glass;

  /// The app's "Reduce transparency" switch: a glass pane is drawn as the
  /// same surface, opaque. `context.glassOpaque` adds the OS's high contrast.
  final bool reduceTransparency;

  /// This device drew the blur too slowly (core/theme/glass_probe.dart): the
  /// panes keep their tint and drop the blur.
  final bool glassBlurOff;

  // Glass values for this theme (tokens.g.dart, `platform.glass` in
  // DraconDex-SDB design/tokens.json).

  /// The blur's standard deviation — CSS `blur(24px)` names the same number.
  double get glassBlur => DdxGlass.glassBlur;

  /// The share of `surface` a pane keeps over the backdrop: the token, raised
  /// for the themes whose text would otherwise fall under 4.5:1 on the worst
  /// backdrop (SDB's generator computes those, nothing here is hand-kept).
  double get glassTint => DdxGlass.glassTintFor(name);

  /// A pane's colour: `surface` at [glassTint].
  Color get glassSurface => palette.surface.withValues(alpha: glassTint);

  /// The hairline round a pane.
  Color get glassStroke => DdxGlass.glassStroke(palette);

  /// A floating pane's lift (a sheet); docked bars have none.
  List<BoxShadow> get glassShadow => DdxGlass.glassShadow;

  /// The two ends of the gradient behind the glass — the theme's bg, and bg
  /// a third of the way to its accent.
  Color get glassBackdropFrom => DdxGlass.glassBackdropFrom(palette);
  Color get glassBackdropTo => DdxGlass.glassBackdropTo(palette);

  /// Muted TEXT — t3 lifted until it reaches 4.5:1 on bg, surface and
  /// raised. Borders and dividers keep [DdxPalette.t3].
  Color get textMuted => palette.t3Aa;
  Color get raised => palette.raised;
  Color get hover => palette.hover;

  /// Text on an accent fill — a selected filter chip, a selected segment.
  /// The palette's own on-accent when it names one; otherwise white while
  /// white reaches 4.5:1, and black when it does not. Seven palettes leave
  /// on-accent implied, and white on their accent lands at 4.2–4.47:1 —
  /// under every one of those accents black reads above 4.5.
  Color get onAccent => palette.onAccent ?? betterInk(palette.accent);

  /// White when it reaches 4.5:1 on [fill]; else [DdxInk.inkDark] when that
  /// does; else black (always ≥ 4.5 where white falls short).
  static Color betterInk(Color fill) {
    const white = Color(0xFFFFFFFF);
    if (contrast(white, fill) >= 4.5) return white;
    if (contrast(DdxInk.inkDark, fill) >= 4.5) return DdxInk.inkDark;
    return const Color(0xFF000000);
  }

  /// WCAG 2 contrast ratio of two opaque colours.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  /// Status colours for "needs attention" (a missing file, nearly full) and
  /// "for your information" (a tip, "new") — APP docs/UX-LAYOUT.md §9. Each
  /// reaches 4.5:1 as text on its own tone's surfaces. Local constants until
  /// DraconDex-SDB publishes warn/info in tokens.g.dart; then read from there.
  bool get _lightTone => palette.bg.computeLuminance() > 0.4;
  Color get warn => _lightTone ? const Color(0xFF92400E) : const Color(0xFFF59E0B);
  Color get info => _lightTone ? const Color(0xFF075985) : const Color(0xFF38BDF8);
  Color get onWarn => _lightTone ? const Color(0xFFFFFFFF) : const Color(0xFF1A1200);
  Color get onInfo => _lightTone ? const Color(0xFFFFFFFF) : const Color(0xFF03202E);

  // The iOS layer (C3): grouped-list separators, the translucent bars, the
  // search field fill, the tint. Derived per theme the same way on both apps.
  Color get iosSeparator => DdxIos.separator(palette);
  Color get iosBar => DdxIos.bar(palette);
  Color get iosFill => DdxIos.fill(palette);
  Color get iosTint => DdxIos.tint(palette);

  @override
  DdxThemeExt copyWith({
    String? name,
    DdxPalette? palette,
    double? radius,
    double? radiusSmall,
    double? radiusLarge,
    bool? glass,
    bool? reduceTransparency,
    bool? glassBlurOff,
  }) =>
      DdxThemeExt(
        name: name ?? this.name,
        palette: palette ?? this.palette,
        radius: radius ?? this.radius,
        radiusSmall: radiusSmall ?? this.radiusSmall,
        radiusLarge: radiusLarge ?? this.radiusLarge,
        glass: glass ?? this.glass,
        reduceTransparency: reduceTransparency ?? this.reduceTransparency,
        glassBlurOff: glassBlurOff ?? this.glassBlurOff,
      );

  /// A theme change snaps the palette (a half-way palette is not a theme
  /// anyone chose) and the style switches, and eases only the shape.
  @override
  DdxThemeExt lerp(ThemeExtension<DdxThemeExt>? other, double t) {
    if (other is! DdxThemeExt) return this;
    final self = t < 0.5;
    return DdxThemeExt(
      name: self ? name : other.name,
      palette: self ? palette : other.palette,
      radius: lerpDouble(radius, other.radius, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      glass: self ? glass : other.glass,
      reduceTransparency: self ? reduceTransparency : other.reduceTransparency,
      glassBlurOff: self ? glassBlurOff : other.glassBlurOff,
    );
  }
}

extension DdxThemeContext on BuildContext {
  /// The active theme's [DdxThemeExt]. Always present under DraconDexApp;
  /// a widget test without it gets midnight rather than a null.
  DdxThemeExt get ddx =>
      Theme.of(this).extension<DdxThemeExt>() ?? DdxThemeExt(name: 'midnight', palette: ddxPalettes['midnight']!);

  /// True on iPhone/iPad — the Apple-app layer (C3). Android keeps Material 3.
  bool get isIosStyle => Theme.of(this).platform == TargetPlatform.iOS;

  /// The Glass UI style is on (Procress 23). Independent of [isIosStyle]:
  /// an iPhone on Glass keeps its large titles and grouped lists.
  bool get isGlassStyle => ddx.glass;

  /// Glass drawn as plain, opaque surface: the app's "Reduce transparency"
  /// switch, or the OS asking for high contrast. Not a cheaper glass — no
  /// translucency and no blur at all.
  bool get glassOpaque => ddx.reduceTransparency || (MediaQuery.maybeHighContrastOf(this) ?? false);
}

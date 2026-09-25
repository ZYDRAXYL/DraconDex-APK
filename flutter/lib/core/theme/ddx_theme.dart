import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Everything the app's widgets need that [ColorScheme] has no slot for —
/// the palette as the desktop names it, muted text that reaches 4.5:1, the
/// radius scale, and the iOS layer's derived colours (APP docs/REDESIGN.md
/// C3, C4, C5). The values come from tokens.g.dart, generated in
/// DraconDex-SDB from the same design/tokens.json EXE's CSS comes from.
///
/// Read it with `context.ddx`.
@immutable
class DdxThemeExt extends ThemeExtension<DdxThemeExt> {
  const DdxThemeExt({required this.name, required this.palette, this.radius = 8, this.radiusSmall = 4, this.radiusLarge = 12});

  /// The theme's key in [ddxPalettes] (midnight, atDusk, …).
  final String name;
  final DdxPalette palette;
  final double radius;
  final double radiusSmall;
  final double radiusLarge;

  /// Muted TEXT — t3 lifted until it reaches 4.5:1 on bg, surface and
  /// raised. Borders and dividers keep [DdxPalette.t3].
  Color get textMuted => palette.t3Aa;
  Color get raised => palette.raised;
  Color get hover => palette.hover;

  // The iOS layer (C3): grouped-list separators, the translucent bars, the
  // search field fill, the tint. Derived per theme the same way on both apps.
  Color get iosSeparator => DdxIos.separator(palette);
  Color get iosBar => DdxIos.bar(palette);
  Color get iosFill => DdxIos.fill(palette);
  Color get iosTint => DdxIos.tint(palette);

  @override
  DdxThemeExt copyWith({String? name, DdxPalette? palette, double? radius, double? radiusSmall, double? radiusLarge}) => DdxThemeExt(
        name: name ?? this.name,
        palette: palette ?? this.palette,
        radius: radius ?? this.radius,
        radiusSmall: radiusSmall ?? this.radiusSmall,
        radiusLarge: radiusLarge ?? this.radiusLarge,
      );

  /// A theme change snaps the palette (a half-way palette is not a theme
  /// anyone chose) and eases only the shape.
  @override
  DdxThemeExt lerp(ThemeExtension<DdxThemeExt>? other, double t) {
    if (other is! DdxThemeExt) return this;
    return DdxThemeExt(
      name: t < 0.5 ? name : other.name,
      palette: t < 0.5 ? palette : other.palette,
      radius: lerpDouble(radius, other.radius, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
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
}

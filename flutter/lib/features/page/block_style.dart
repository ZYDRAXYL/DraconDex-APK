import 'package:flutter/material.dart';

import '../../core/theme/ddx_theme.dart';

/// Block style on the phone — the port of EXE renderer/page/style.js (APP
/// docs/TEMPLATES.md §6). Every block may carry `config.style`: a variant,
/// an accent NAME (never a free colour, so the theme still owns the page),
/// width, align, density, a header, collapsible, an anchor and hideOn. A
/// value this app does not know — a template from a newer version — is
/// dropped here, never an error, and a block without a style draws exactly
/// as it did before.
class BlockStyle {
  static const values = {
    'variant': ['plain', 'card', 'outline', 'tinted', 'hero'],
    'accent': ['kind', 'accent', 'blue', 'green', 'amber', 'rose', 'violet', 'slate'],
    'width': ['narrow', 'normal', 'wide', 'full'],
    'align': ['left', 'center', 'right'],
    'density': ['comfy', 'compact'],
    'collapsible': ['off', 'open', 'closed'],
    'hideOn': ['none', 'phone', 'tablet', 'desktop'],
  };
  static const defaults = {
    'variant': 'plain', 'accent': 'accent', 'width': 'normal', 'align': 'left', //
    'density': 'comfy', 'collapsible': 'off', 'hideOn': 'none',
  };

  final Map<String, String> _v;
  final bool headerShow;
  final String headerTitle, headerIcon, anchor;
  const BlockStyle._(this._v, this.headerShow, this.headerTitle, this.headerIcon, this.anchor);

  String get variant => _v['variant']!;
  String get accent => _v['accent']!;
  String get width => _v['width']!;
  String get align => _v['align']!;
  String get density => _v['density']!;
  String get collapsible => _v['collapsible']!;
  String get hideOn => _v['hideOn']!;
  String operator [](String key) => _v[key] ?? '';

  factory BlockStyle.of(Map<String, Object?> config) {
    final raw = config['style'];
    final s = raw is Map ? raw.cast<String, Object?>() : const <String, Object?>{};
    final v = {for (final e in values.entries) e.key: e.value.contains(s[e.key]) ? s[e.key] as String : defaults[e.key]!};
    final h = s['header'] is Map ? (s['header'] as Map).cast<String, Object?>() : const <String, Object?>{};
    String cut(Object? o, int n) => o is String ? (o.length > n ? o.substring(0, n) : o) : '';
    return BlockStyle._(v, h['show'] == true, cut(h['title'], 80), cut(h['icon'], 80), cleanAnchor(s['anchor']));
  }

  /// The desktop's pbAnchorClean.
  static String cleanAnchor(Object? s) {
    final v = '${s ?? ''}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return v.length > 40 ? v.substring(0, 40) : v;
  }

  bool get collapses => collapsible != 'off';
  bool get hasHeader => headerShow || collapses;
  bool get isPlain => variant == 'plain' && !hasHeader && align == 'left' && density == 'comfy' && width == 'normal';
}

/// `config.style` with one value set — a default removes the key, as the
/// desktop's pbStyleSet does, so a reset block stores nothing.
Map<String, Object?> styleWith(Map<String, Object?> config, String key, String value) {
  final style = {...?(config['style'] as Map?)?.cast<String, Object?>()};
  if (key == 'anchor') {
    final a = BlockStyle.cleanAnchor(value);
    if (a.isEmpty) {
      style.remove('anchor');
    } else {
      style['anchor'] = a;
    }
  } else if (BlockStyle.values[key]?.contains(value) ?? false) {
    if (value == BlockStyle.defaults[key]) {
      style.remove(key);
    } else {
      style[key] = value;
    }
  }
  return {...config, 'style': style.isEmpty ? null : style}..removeWhere((k, v) => k == 'style' && v == null);
}

/// `config.style.header` patched; an empty header is removed.
Map<String, Object?> styleHeaderWith(Map<String, Object?> config, {bool? show, String? title, String? icon}) {
  final style = {...?(config['style'] as Map?)?.cast<String, Object?>()};
  final h = {...?(style['header'] as Map?)?.cast<String, Object?>()};
  if (show != null) h['show'] = show;
  if (title != null) h['title'] = title.trim();
  if (icon != null) h['icon'] = icon;
  if (h['show'] != true && '${h['title'] ?? ''}'.isEmpty && '${h['icon'] ?? ''}'.isEmpty) {
    style.remove('header');
  } else {
    style['header'] = h;
  }
  final out = {...config};
  if (style.isEmpty) {
    out.remove('style');
  } else {
    out['style'] = style;
  }
  return out;
}

/// An accent name as a colour: bound to the theme for 'accent', fixed hues
/// for the rest — the same values as EXE css/page-style.css.
Color accentColor(BuildContext context, String name) => switch (name) {
      'kind' => const Color(0xFF38BDF8),
      'blue' => const Color(0xFF3B82F6),
      'green' => const Color(0xFF10B981),
      'amber' => const Color(0xFFD97706),
      'rose' => const Color(0xFFE11D48),
      'violet' => const Color(0xFF8B5CF6),
      'slate' => const Color(0xFF64748B),
      _ => Theme.of(context).colorScheme.primary,
    };

/// The hero's ground: the accent darkened 40–56%, which keeps white text at
/// ≥ 5.4:1 for every accent (EXE test/block-style.test.mjs).
List<Color> heroColors(Color acc) => [Color.lerp(acc, Colors.black, .40)!, Color.lerp(acc, Colors.black, .56)!];

/// A header icon as the app stores them: `sym:<glyph>` draws the glyph; an
/// `svg:` key names a desktop icon the phone does not carry, so nothing.
Widget? headerIconOf(String icon, Color color) =>
    icon.startsWith('sym:') && icon.length > 4 ? Text(icon.substring(4), style: TextStyle(fontSize: 16, color: color)) : null;

/// The page's size as the desktop's container queries read it (EXE
/// css/page.css, APP Procress 16 part 3b): a phone up to 560 wide, a tablet
/// up to 1023, then a PC. Column widths (`rowWidths`) and `hideOn` follow it.
String pageFrameFor(double width) => width <= 560 ? 'phone' : (width <= 1023 ? 'tablet' : 'pc');

/// The width the page itself has, set by ModulePage — on a tablet the rail and
/// the hub panel take their share of the window. Without one (a sheet, a
/// test), the window's.
class PageFrameScope extends InheritedWidget {
  final String frame;
  const PageFrameScope({super.key, required this.frame, required super.child});

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageFrameScope>()?.frame ?? pageFrameFor(MediaQuery.sizeOf(context).width);

  @override
  bool updateShouldNotify(PageFrameScope oldWidget) => oldWidget.frame != frame;
}

/// One block drawn in its style: the variant's ground, a header (with the
/// fold when collapsible), alignment and density. [name] is the header's
/// default title. [arranging]: hidden blocks show (dimmed) so they can be
/// found again.
class StyledBlock extends StatefulWidget {
  final Map<String, Object?> config;
  final String name;
  final Widget child;
  final bool arranging;

  /// An element page's main text: a style must never hide content (§6.4).
  final bool isBody;

  const StyledBlock({super.key, required this.config, required this.name, required this.child, this.arranging = false, this.isBody = false});

  @override
  State<StyledBlock> createState() => _StyledBlockState();
}

class _StyledBlockState extends State<StyledBlock> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final st = BlockStyle.of(widget.config);
    if (st.isPlain && st.hideOn == 'none') return widget.child;
    final frame = PageFrameScope.of(context);
    // desktop = wider than a phone (EXE css/page.css)
    final hidden = !widget.isBody && (st.hideOn == frame || (st.hideOn == 'desktop' && frame != 'phone'));
    if (hidden && !widget.arranging) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final acc = accentColor(context, st.accent);
    final hero = st.variant == 'hero';
    final compact = st.density == 'compact';
    final open = !st.collapses || (_open ?? st.collapsible == 'open');
    final align = switch (st.align) { 'center' => TextAlign.center, 'right' => TextAlign.right, _ => TextAlign.left };
    final cross = switch (st.align) { 'center' => CrossAxisAlignment.center, 'right' => CrossAxisAlignment.end, _ => CrossAxisAlignment.stretch };

    final ink = hero ? Colors.white : theme.colorScheme.onSurface;
    Widget? header;
    if (st.hasHeader) {
      final icon = headerIconOf(st.headerIcon, hero ? Colors.white : acc);
      final row = Row(
        mainAxisAlignment: switch (st.align) { 'center' => MainAxisAlignment.center, 'right' => MainAxisAlignment.end, _ => MainAxisAlignment.start },
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 8)],
          Flexible(
            child: Text(st.headerTitle.isEmpty ? widget.name : st.headerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: hero ? 19 : 14, color: ink)),
          ),
          if (st.collapses) ...[
            if (st.align == 'left') const Spacer() else const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0 : -.25,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.expand_more, size: 20, color: hero ? Colors.white : context.ddx.textMuted),
            ),
          ],
        ],
      );
      header = Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, open ? 8 : 0),
        child: st.collapses
            ? Semantics(
                button: true,
                expanded: open,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _open = !open),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: row),
                ),
              )
            : row,
      );
    }

    Widget body = widget.child;
    if (st.align != 'left') body = DefaultTextStyle.merge(textAlign: align, child: body);
    if (hero) {
      // white belongs to the hero's own ground; the theme's text colours
      // follow so a component's own Text reads on it
      body = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
          iconTheme: theme.iconTheme.copyWith(color: Colors.white),
          colorScheme: theme.colorScheme.copyWith(onSurface: Colors.white, onSurfaceVariant: const Color(0xFFECECF2)),
        ),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: body),
      );
    }
    final content = Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: [?header, if (open) body]);

    Widget out;
    if (st.variant == 'plain') {
      out = Padding(padding: EdgeInsets.only(top: header != null ? 8 : 0), child: content);
    } else {
      final radius = BorderRadius.circular(context.ddx.radius);
      final bg = theme.scaffoldBackgroundColor;
      final decoration = switch (st.variant) {
        'card' => BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: radius,
            border: Border.all(color: theme.dividerColor),
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))]),
        'outline' => BoxDecoration(borderRadius: radius, border: Border.all(color: Color.lerp(theme.dividerColor, acc, .55)!)),
        'tinted' => BoxDecoration(
            color: Color.alphaBlend(acc.withValues(alpha: .12), bg),
            borderRadius: radius,
            border: Border(left: BorderSide(color: acc, width: 3))),
        _ => BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: heroColors(acc))),
      };
      // the block's own content keeps its 16px inset, so the ground sits
      // 8px out from the page's edge rather than pushing the text further in
      out = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: hero ? (compact ? 12 : 20) : (compact ? 6 : 12)),
            child: content,
          ),
        ),
      );
    }
    if (st.width == 'narrow') {
      out = Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: out));
    }
    return hidden ? Opacity(opacity: .62, child: out) : out;
  }
}

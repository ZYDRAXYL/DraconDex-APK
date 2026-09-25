import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/ddx_theme.dart';
import '../../core/theme/tokens.g.dart';

/// Every theme the desktop has (Procress 13 part 5): the same 32 palettes,
/// from tokens.g.dart. Folded, it shows the three basics — plus the current
/// theme when that is not one of them — the way the desktop's Appearance
/// page does; unfolded, all of them.
class ThemePickerSection extends ConsumerStatefulWidget {
  const ThemePickerSection({super.key});

  @override
  ConsumerState<ThemePickerSection> createState() => _ThemePickerSectionState();
}

class _ThemePickerSectionState extends ConsumerState<ThemePickerSection> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(settingsProvider).theme;
    final names = AppTheme.names;
    final shown = _all ? names : {...names.take(3), current}.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(l10n.themeLabel, style: Theme.of(context).textTheme.titleMedium)),
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? l10n.themeShowLess : l10n.themeShowAll),
            ),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, c) {
            // ~120dp cards: 3 across on a phone, more on a tablet.
            final cols = (c.maxWidth / 120).floor().clamp(3, 8);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                for (final n in shown)
                  _ThemeCard(
                    name: n,
                    palette: ddxPalettes[n]!,
                    selected: n == current,
                    onTap: () => ref.read(settingsProvider.notifier).setTheme(n),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// A theme drawn as a tiny app: a sidebar, two muted lines and a button in
/// the theme's own colours — the desktop's card, not just a swatch.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.name, required this.palette, required this.selected, required this.onTap});

  final String name;
  final DdxPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final p = palette;
    return Semantics(
      button: true,
      selected: selected,
      label: AppTheme.label(name),
      child: InkWell(
        borderRadius: BorderRadius.circular(ddx.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ddx.radius),
            border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : ddx.palette.border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius: BorderRadius.circular(ddx.radiusSmall),
                    border: Border.all(color: p.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(children: [
                    Container(
                      width: 16,
                      color: p.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                      child: Column(children: [
                        Container(height: 3, color: p.accent),
                        const SizedBox(height: 3),
                        Container(height: 3, color: p.raised),
                      ]),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(widthFactor: .8, child: Container(height: 3, color: p.t2)),
                            const SizedBox(height: 3),
                            FractionallySizedBox(widthFactor: .6, child: Container(height: 3, color: p.t3Aa)),
                            const Spacer(),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(width: 22, height: 7, decoration: BoxDecoration(color: p.button ?? p.accent, borderRadius: BorderRadius.circular(3))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(AppTheme.label(name), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium),
                ),
                if (selected) Icon(Icons.check, size: 14, color: Theme.of(context).colorScheme.primary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide ColorModel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/color_model.dart';
import '../providers/color_provider.dart';
import '../providers/db_providers.dart';
import 'color_dot.dart';

class ColorPickerSheet extends ConsumerStatefulWidget {
  final String? currentColorCode;
  final void Function(ColorModel color) onColorSelected;

  const ColorPickerSheet({
    super.key,
    this.currentColorCode,
    required this.onColorSelected,
  });

  @override
  ConsumerState<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<ColorPickerSheet> {
  Color _pickerColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    final colorsAsync = ref.watch(colorsProvider);
    final recentAsync = ref.watch(recentColorsProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  recentAsync.when(
                    data: (recent) => _section('Recent', recent, theme),
                    loading: () => const SizedBox(),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 16),
                  colorsAsync.when(
                    data: (colors) => _section('All Colors', colors, theme),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 16),
                  Text('Custom', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  HueRingPicker(
                    pickerColor: _pickerColor,
                    onColorChanged: (c) => setState(() => _pickerColor = c),
                    enableAlpha: false,
                    displayThumbColor: true,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      final hex = '#${_pickerColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                      final navigator = Navigator.of(context);
                      final dao = ref.read(colorDaoProvider);
                      dao.whenData((d) async {
                        await d.addColor(hex);
                        final colors = await d.getColors();
                        final found = colors.where((c) => c.colorCode.toUpperCase() == hex).firstOrNull;
                        if (found != null && mounted) widget.onColorSelected(found);
                        if (mounted) navigator.pop();
                      });
                    },
                    child: const Text('Use Custom Color'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<ColorModel> colors, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) {
            final selected = c.colorCode == widget.currentColorCode;
            return GestureDetector(
              onTap: () {
                widget.onColorSelected(c);
                Navigator.of(context).pop();
                final dao = ref.read(colorDaoProvider);
                dao.whenData((d) => d.markColorUsed(c.id));
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hexToColor(c.colorCode),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Future<void> showColorPicker(
  BuildContext context,
  WidgetRef ref, {
  String? currentColorCode,
  required void Function(ColorModel color) onColorSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ColorPickerSheet(
      currentColorCode: currentColorCode,
      onColorSelected: onColorSelected,
    ),
  );
}

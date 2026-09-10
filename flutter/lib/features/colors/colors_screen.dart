import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide ColorModel;
import '../../core/i18n/app_localizations.dart';
import '../../providers/color_provider.dart';
import '../../providers/db_providers.dart';
import '../../widgets/color_dot.dart';
import '../../widgets/confirm_dialog.dart';

class ColorsScreen extends ConsumerWidget {
  const ColorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorsAsync = ref.watch(colorsProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.colorPaletteTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddColorDialog(context, ref, l10n),
        child: const Icon(Icons.add),
      ),
      body: colorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (colors) {
          if (colors.isEmpty) return Center(child: Text(l10n.noColors));
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 80,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (ctx, i) {
              final c = colors[i];
              return GestureDetector(
                onLongPress: () => showConfirmDialog(ctx, title: l10n.removeColorConfirmTitle).then((ok) async {
                  if (!ok) return;
                  final deleted = await ref.read(colorDaoProvider).when(
                    data: (d) => d.deleteColor(c.id),
                    loading: () => Future.value(false),
                    error: (_, _) => Future.value(false),
                  );
                  if (!deleted && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(l10n.colorInUse)),
                    );
                  } else {
                    ref.invalidate(colorsProvider);
                  }
                }),
                child: Tooltip(
                  message: c.colorCode,
                  child: ColorDot(colorCode: c.colorCode, size: 48),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddColorDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    Color picked = Colors.blue;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addColorTitle),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              final hex = '#${picked.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              await ref.read(colorDaoProvider).when(
                data: (d) => d.addColor(hex),
                loading: () async {},
                error: (_, _) async {},
              );
              ref.invalidate(colorsProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.btnAdd),
          ),
        ],
      ),
    );
  }
}

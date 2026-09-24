import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/db_providers.dart';

/// Renames a module (kind is fixed once created). A new module starts in
/// the grouped kind sheet (new_module_sheet.dart); the create path here is
/// what that sheet does not need — a bare name for a given kind.
class ModuleDialog extends ConsumerStatefulWidget {
  final int nexusId;
  final int? parentId;
  final ModuleModel? existing;

  const ModuleDialog({super.key, required this.nexusId, this.parentId, this.existing});

  @override
  ConsumerState<ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends ConsumerState<ModuleDialog> {
  late final TextEditingController _name;
  late ModuleKind _kind;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _kind = widget.existing?.kind ?? ModuleKind.collector;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? l10n.newModuleTitle : l10n.renameModuleTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: '${l10n.labelName} *')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.btnSave)),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // See NexusDialog._save() for why this is wrapped in try/catch rather
    // than swallowing errors — a failed createModule/renameModule used to
    // look identical to a successful one from this dialog's point of view.
    try {
      await ref.read(moduleDaoProvider).when(
        data: (d) async {
          if (widget.existing == null) {
            await d.createModule(nexusRef: widget.nexusId, parentId: widget.parentId, name: name, kind: _kind);
          } else {
            await d.renameModule(widget.existing!.id, name);
          }
        },
        loading: () => throw StateError('database not ready'),
        error: (e, s) => throw e,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailedMessage} $e')));
    }
  }
}

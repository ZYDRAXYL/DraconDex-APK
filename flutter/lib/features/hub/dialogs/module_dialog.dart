import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/db_providers.dart';

/// Create a new module (name + kind picker) or rename an existing one
/// (kind is fixed once created).
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
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(isNew ? l10n.newModuleTitle : l10n.renameModuleTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: '${l10n.labelName} *')),
            if (isNew) ...[
              const SizedBox(height: 16),
              Text(l10n.labelKind, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: double.maxFinite,
                height: 240,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  // Diviner is opened, not created, here: this app's pinned
                  // vault schema (sdb.lock.json) predates 'diviner' in the
                  // module.kind CHECK, so an INSERT would be refused.
                  children: ModuleKind.values.where((k) => k != ModuleKind.diviner).map((k) {
                    final info = moduleKindInfo[k]!;
                    final selected = _kind == k;
                    return InkWell(
                      onTap: () => setState(() => _kind = k),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected ? theme.colorScheme.primary : theme.dividerColor,
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(info.icon, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              info.label,
                              style: theme.textTheme.labelSmall,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),
              Text(moduleKindInfo[_kind]!.description, style: theme.textTheme.bodySmall),
              if (!moduleKindInfo[_kind]!.contentImplemented) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.kindContentUnavailable,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ],
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

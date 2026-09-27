import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/chronicler_model.dart';
import '../../../data/models/module_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../page/views/view_common.dart';

/// Chronicler kind: the module's timeline, in chronological order.
///
/// Dates are entered as plain numbers rather than through a date picker: a
/// Nexus can run on an invented calendar (`calendar_template`), so month 13
/// or year -400 has to be expressible. The ordering the DAO applies is
/// numeric for the same reason.
class ChroniclerContent extends ConsumerWidget {
  final int moduleId;
  /// The module, when the page has it: with no events yet the kind's empty
  /// state (KindEmptyState) stands in for the event list.
  final ModuleModel? module;
  const ChroniclerContent({super.key, required this.moduleId, this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timelineAsync = ref.watch(timelineProvider(moduleId));

    return timelineAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (timelineId) =>
          timelineId == null ? const SizedBox.shrink() : _Events(timelineId: timelineId, module: module),
    );
  }
}

class _Events extends ConsumerWidget {
  final int timelineId;
  final ModuleModel? module;
  const _Events({required this.timelineId, this.module});

  Future<void> _edit(BuildContext context, WidgetRef ref, {TimelineEventModel? existing}) async {
    final result = await showDialog<_EventDraft>(
      context: context,
      builder: (ctx) => _EventDialog(existing: existing),
    );
    if (result == null) return;
    final dao = ref.read(chroniclerDaoProvider).valueOrNull;
    if (dao == null) return;

    final startId = await dao.ensureDate(
      day: result.day, month: result.month, years: result.years,
      hour: result.hour, minute: result.minute,
    );
    int? endId;
    if (result.hasEnd) {
      endId = await dao.ensureDate(
        day: result.endDay, month: result.endMonth, years: result.endYears,
      );
    }

    if (existing == null) {
      await dao.createEvent(
        timelineId: timelineId, startDateId: startId,
        name: result.name, story: result.story, endDateId: endId,
      );
    } else {
      await dao.updateEvent(
        existing.id, startDateId: startId,
        name: result.name, story: result.story, endDateId: endId,
      );
    }
    ref.invalidate(timelineEventsProvider(timelineId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TimelineEventModel e) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.confirmDeleteMessage,
    );
    if (!ok) return;
    final dao = ref.read(chroniclerDaoProvider).valueOrNull;
    await dao?.deleteEvent(e.id);
    ref.invalidate(timelineEventsProvider(timelineId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(timelineEventsProvider(timelineId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text(l10n.chroniclerEvents, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.chroniclerNewEvent),
              ),
            ],
          ),
        ),
        eventsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
          ),
          data: (events) {
            if (events.isEmpty && module != null) {
              return KindEmptyState(module: module!, note: l10n.chroniclerNoEvents, startLabel: l10n.chroniclerNewEvent, onStart: () => _edit(context, ref));
            }
            if (events.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.chroniclerNoEvents, style: theme.textTheme.bodySmall),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  for (final e in events)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 4,
                        height: 36,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        e.name?.isNotEmpty == true ? e.name! : l10n.chroniclerUntitledEvent,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        e.end == null ? e.start.label : '${e.start.label} → ${e.end!.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => _edit(context, ref, existing: e),
                      trailing: IconButton(
                        tooltip: l10n.btnDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _delete(context, ref, e),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// What the dialog hands back. A plain value rather than a partially-saved
/// row, so nothing touches the database until the caller commits it.
class _EventDraft {
  final String? name;
  final String? story;
  final int day, month, years, hour, minute;
  final bool hasEnd;
  final int endDay, endMonth, endYears;

  const _EventDraft({
    this.name,
    this.story,
    required this.day,
    required this.month,
    required this.years,
    this.hour = 0,
    this.minute = 0,
    this.hasEnd = false,
    this.endDay = 1,
    this.endMonth = 1,
    this.endYears = 0,
  });
}

class _EventDialog extends StatefulWidget {
  final TimelineEventModel? existing;
  const _EventDialog({this.existing});

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _name;
  late final TextEditingController _story;
  late final TextEditingController _day, _month, _years, _hour, _minute;
  late final TextEditingController _endDay, _endMonth, _endYears;
  late bool _hasEnd;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _story = TextEditingController(text: e?.story ?? '');
    _day = TextEditingController(text: '${e?.start.day ?? 1}');
    _month = TextEditingController(text: '${e?.start.month ?? 1}');
    _years = TextEditingController(text: '${e?.start.years ?? 0}');
    _hour = TextEditingController(text: '${e?.start.hour ?? 0}');
    _minute = TextEditingController(text: '${e?.start.minute ?? 0}');
    _hasEnd = e?.end != null;
    _endDay = TextEditingController(text: '${e?.end?.day ?? 1}');
    _endMonth = TextEditingController(text: '${e?.end?.month ?? 1}');
    _endYears = TextEditingController(text: '${e?.end?.years ?? 0}');
  }

  @override
  void dispose() {
    for (final c in [_name, _story, _day, _month, _years, _hour, _minute,
                     _endDay, _endMonth, _endYears]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, int fallback) => int.tryParse(c.text.trim()) ?? fallback;

  Widget _num(TextEditingController c, String label) => SizedBox(
        width: 72,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.chroniclerNewEvent : l10n.btnEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.labelName),
            ),
            const SizedBox(height: 12),
            Text(l10n.chroniclerStart, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _num(_years, l10n.chroniclerYear),
              _num(_month, l10n.chroniclerMonth),
              _num(_day, l10n.chroniclerDay),
              _num(_hour, l10n.chroniclerHour),
              _num(_minute, l10n.chroniclerMinute),
            ]),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _hasEnd,
              onChanged: (v) => setState(() => _hasEnd = v ?? false),
              title: Text(l10n.chroniclerHasEnd),
            ),
            if (_hasEnd)
              Wrap(spacing: 8, runSpacing: 8, children: [
                _num(_endYears, l10n.chroniclerYear),
                _num(_endMonth, l10n.chroniclerMonth),
                _num(_endDay, l10n.chroniclerDay),
              ]),
            const SizedBox(height: 12),
            TextField(
              controller: _story,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.chroniclerStory,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.btnCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_EventDraft(
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            story: _story.text.trim().isEmpty ? null : _story.text.trim(),
            day: _int(_day, 1),
            month: _int(_month, 1),
            years: _int(_years, 0),
            hour: _int(_hour, 0),
            minute: _int(_minute, 0),
            hasEnd: _hasEnd,
            endDay: _int(_endDay, 1),
            endMonth: _int(_endMonth, 1),
            endYears: _int(_endYears, 0),
          )),
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}

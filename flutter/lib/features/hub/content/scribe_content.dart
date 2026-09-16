import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/scribe_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/confirm_dialog.dart';

/// Scribe kind: chat-style notes. Sessions across the top, the selected
/// session's transcript below, and a composer that appends to it.
///
/// Unlike Author's long-form editor this saves per message rather than on
/// blur — a chat line is short and the user expects it committed the moment
/// they send it.
class ScribeContent extends ConsumerStatefulWidget {
  final int moduleId;
  const ScribeContent({super.key, required this.moduleId});

  @override
  ConsumerState<ScribeContent> createState() => _ScribeContentState();
}

class _ScribeContentState extends ConsumerState<ScribeContent> {
  int? _selectedId;

  Future<void> _addSession() async {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.read(scribeDaoProvider).valueOrNull;
    if (dao == null) return;
    final id = await dao.createSession(moduleRef: widget.moduleId, name: l10n.scribeNewSession);
    if (!mounted) return;
    setState(() => _selectedId = id);
    ref.invalidate(chatSessionsProvider(widget.moduleId));
  }

  Future<void> _deleteSession(ChatSessionModel s) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.confirmDeleteTitle,
      message: l10n.confirmDeleteMessage,
    );
    if (!ok) return;
    final dao = ref.read(scribeDaoProvider).valueOrNull;
    await dao?.deleteSession(s.id);
    if (!mounted) return;
    if (_selectedId == s.id) setState(() => _selectedId = null);
    ref.invalidate(chatSessionsProvider(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(chatSessionsProvider(widget.moduleId));

    return sessionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (sessions) {
        final selected = sessions.where((s) => s.id == _selectedId).firstOrNull ??
            (sessions.isEmpty ? null : sessions.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(l10n.scribeSessions, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addSession,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.scribeNewSession),
                  ),
                ],
              ),
            ),
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(l10n.scribeNoSessions, style: theme.textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final s = sessions[i];
                    return ChoiceChip(
                      label: Text(s.name, overflow: TextOverflow.ellipsis),
                      selected: selected?.id == s.id,
                      onSelected: (_) => setState(() => _selectedId = s.id),
                    );
                  },
                ),
              ),
              if (selected != null)
                _Transcript(
                  key: ValueKey(selected.id),
                  session: selected,
                  onDeleteSession: () => _deleteSession(selected),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Transcript extends ConsumerStatefulWidget {
  final ChatSessionModel session;
  final VoidCallback onDeleteSession;

  const _Transcript({super.key, required this.session, required this.onDeleteSession});

  @override
  ConsumerState<_Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends ConsumerState<_Transcript> {
  final _composer = TextEditingController();

  /// Which side the next message lands on. Kept in the widget rather than the
  /// database because it is a composing preference, not part of the note.
  bool _right = true;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final dao = ref.read(scribeDaoProvider).valueOrNull;
    if (dao == null) return;
    await dao.addMessage(
      sessionRef: widget.session.id,
      message: text,
      side: _right ? 'r' : 'l',
    );
    _composer.clear();
    ref.invalidate(chatMessagesProvider(widget.session.id));
  }

  Future<void> _deleteMessage(ChatMessageModel m) async {
    final dao = ref.read(scribeDaoProvider).valueOrNull;
    await dao?.deleteMessage(m.id);
    ref.invalidate(chatMessagesProvider(widget.session.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.session.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.session.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l10n.btnDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: widget.onDeleteSession,
              ),
            ],
          ),
          const SizedBox(height: 4),
          messagesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (messages) => Column(
              children: [
                for (final m in messages)
                  Align(
                    alignment: m.isRight ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: GestureDetector(
                      onLongPress: () => _deleteMessage(m),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: m.isRight
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(m.message),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: l10n.scribeSwitchSide,
                icon: Icon(_right ? Icons.format_align_right : Icons.format_align_left, size: 20),
                onPressed: () => setState(() => _right = !_right),
              ),
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: l10n.scribeMessageHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                tooltip: l10n.btnAdd,
                icon: const Icon(Icons.send, size: 20),
                onPressed: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

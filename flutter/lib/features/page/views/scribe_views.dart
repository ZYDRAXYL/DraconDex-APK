import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../providers/module_content_provider.dart';
import '../../../widgets/markdown_view.dart';
import '../../hub/content/scribe_content.dart';
import '../component_registry.dart';
import 'view_common.dart';

/// The Scribe's two presets (EXE mod/chatscribe.js CHATSCRIBE_VIEWS): chat,
/// and the transcript — one session's messages as a timed document.
class ScribeView extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const ScribeView({super.key, required this.ctx});

  @override
  ConsumerState<ScribeView> createState() => _ScribeViewState();
}

class _ScribeViewState extends ConsumerState<ScribeView> {
  int? _session;

  @override
  Widget build(BuildContext context) {
    final id = widget.ctx.source.id;
    if (widget.ctx.preset != 'transcript') return ScribeContent(moduleId: id, module: widget.ctx.source);
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessions = ref.watch(chatSessionsProvider(id)).valueOrNull;
    if (sessions == null) return const SizedBox(height: 48);
    if (sessions.isEmpty) return ScribeContent(moduleId: id, module: widget.ctx.source);
    final ses = sessions.where((s) => s.id == _session).firstOrNull ?? sessions.first;
    final msgs = ref.watch(chatMessagesProvider(ses.id)).valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButton<int>(
          value: ses.id,
          isExpanded: true,
          items: [for (final s in sessions) DropdownMenuItem(value: s.id, child: Text(s.name))],
          onChanged: (v) => setState(() => _session = v),
        ),
        if (msgs.isEmpty) EmptyHint(l.scribeNoMessages),
        for (final m in msgs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 92,
                child: Text(m.createdAt.length >= 16 ? m.createdAt.substring(0, 16) : m.createdAt,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
              ),
              Expanded(child: MarkdownView(text: m.message, nexusId: widget.ctx.nexusId)),
            ]),
          ),
      ]),
    );
  }
}

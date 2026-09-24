import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/search_service.dart';
import '../providers/navigation_providers.dart';

/// A text field that completes `[[` names (APP docs/APK-V3.md §6, V5.md
/// §8.4 — every free-text field can hold links). Typing `[[` and a few
/// letters lists the Nexus's matching names under the field; tapping one
/// finishes the link. The desktop's core/wiki-field.js, with the suggestion
/// list inline rather than floating, because a floating list over a phone
/// keyboard has nowhere to go.
class WikiTextField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final int nexusId;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const WikiTextField({
    super.key,
    required this.controller,
    required this.nexusId,
    this.focusNode,
    this.decoration,
    this.minLines,
    this.maxLines,
    this.onChanged,
    this.autofocus = false,
  });

  /// The name being typed after an unclosed `[[` right before the cursor.
  static String? openLinkBefore(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    final m = RegExp(r'\[\[([^\[\]|\n]*)$').firstMatch(text.substring(0, cursor));
    return m?.group(1);
  }

  @override
  ConsumerState<WikiTextField> createState() => _WikiTextFieldState();
}

class _WikiTextFieldState extends ConsumerState<WikiTextField> {
  String? _typing;

  void _update() {
    final sel = widget.controller.selection;
    final next = sel.isCollapsed ? WikiTextField.openLinkBefore(widget.controller.text, sel.baseOffset) : null;
    if (next != _typing) setState(() => _typing = next);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _pick(String name) {
    final c = widget.controller;
    final cursor = c.selection.baseOffset;
    final start = c.text.substring(0, cursor).lastIndexOf('[[') + 2;
    final after = c.text.substring(cursor);
    final close = after.startsWith(']]') ? '' : ']]';
    final text = c.text.substring(0, start) + name + close + after;
    final at = start + name.length + 2;
    c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at));
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final typing = _typing;
    final index = typing == null ? null : ref.watch(nexusIndexProvider(widget.nexusId)).valueOrNull;
    final hits = index == null || typing!.isEmpty
        ? const []
        : SearchService.rankItems(index, typing, loose: true).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: widget.decoration,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
        ),
        if (hits.isNotEmpty)
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final it in hits)
                  ListTile(
                    dense: true,
                    leading: Icon(it.itemKind == 'module' ? Icons.folder_outlined : Icons.article_outlined, size: 18),
                    title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: it.itemKind == 'module' ? null : Text(it.moduleName, maxLines: 1),
                    onTap: () => _pick(it.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

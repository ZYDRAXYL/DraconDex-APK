import 'package:flutter/material.dart';

import '../../core/theme/ddx_theme.dart';
import '../../data/services/export/export_service.dart';

/// The right-hand pane of the Export sheet (mockup 11-export; the desktop's
/// exportPreviewHtml): a sketch of the file in its own shape — a paper page
/// that follows paper, orientation, header/footer and the contents page; Word
/// with its Navigation pane; a book; a sheet; the zip's file tree — named
/// from the module's real elements. Grey bars stand in for body text.
class ExportPreview extends StatelessWidget {
  const ExportPreview({
    super.key,
    required this.format,
    required this.prefs,
    required this.title,
    required this.kindLabel,
    required this.names,
    required this.isItem,
  });

  final ExportFormat format;
  final ExportPrefs prefs;
  final String title, kindLabel;
  final List<String> names;
  final bool isItem;

  static const _ink = Color(0xFF1A1A1A);

  List<String> get _shown => (names.isEmpty ? [title] : names).take(6).toList();
  String? get _more => names.length > 6 ? '+${names.length - 6}' : null;

  @override
  Widget build(BuildContext context) => switch (format) {
    ExportFormat.pdf || ExportFormat.docx => _pages(context),
    ExportFormat.epub => _book(context),
    ExportFormat.xlsx => _sheet(context),
    ExportFormat.csv => _tree(context, '$title.csv', [title, ..._shown], plain: true),
    ExportFormat.html => _tree(context, '$title.zip', ['index.html', 'style.css', for (final n in _shown) '$n.html', 'img/']),
    ExportFormat.md => _tree(context, '$title.zip', [for (final n in _shown) '$n.md', 'assets/']),
    ExportFormat.mddx => _tree(context, '$title.ddata + .dpage', [kindLabel, ..._shown], plain: true),
    ExportFormat.dxpack => _tree(context, '$title.dxpack', ['pack.json', 'snapshot.json', 'Assets/$title/']),
  };

  Widget _bars(int n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < n; i++)
        FractionallySizedBox(
          widthFactor: const [.96, .88, .92, .7, .84, .6][i % 6],
          child: Container(
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            decoration: BoxDecoration(color: _ink.withValues(alpha: .14), borderRadius: BorderRadius.circular(3)),
          ),
        ),
    ],
  );

  Widget _paper({required double ratio, required List<Widget> children, bool word = false}) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: AspectRatio(
      aspectRatio: ratio,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 18, offset: Offset(0, 5))],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: _ink, fontSize: 9, fontFamily: word ? 'Calibri' : null),
          child: ClipRect(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ),
      ),
    ),
  );

  Widget _pages(BuildContext context) {
    final word = format == ExportFormat.docx;
    final (w, h) = switch (word ? 'A4' : prefs.paper) {
      'Letter' => (216.0, 279.0),
      'A5' => (148.0, 210.0),
      _ => (210.0, 297.0),
    };
    final land = !word && prefs.orientation == 'landscape';
    final ratio = land ? h / w : w / h;
    final hf = !word && prefs.headerFooter;
    final toc = !word && prefs.toc && prefs.scope == 'module' && !isItem;
    final rule = BorderSide(color: _ink.withValues(alpha: .25));
    Widget small(String a, String b) => DefaultTextStyle.merge(
      style: TextStyle(fontSize: 7, color: _ink.withValues(alpha: .6)),
      child: Row(children: [Expanded(child: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis)), Text(b)]),
    );
    final page = _paper(ratio: ratio, word: word, children: [
      if (hf) Container(padding: const EdgeInsets.only(bottom: 3), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(border: Border(bottom: rule)), child: small(title, '')),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: word ? const Color(0xFF1F3864) : _ink)),
      Text(kindLabel, style: TextStyle(fontSize: 8, color: _ink.withValues(alpha: .6))),
      const SizedBox(height: 6),
      _bars(4),
      Container(width: 70, height: 7, margin: const EdgeInsets.only(top: 8, bottom: 4), color: _ink.withValues(alpha: .5)),
      _bars(3),
      const Spacer(),
      if (hf) Container(padding: const EdgeInsets.only(top: 3), decoration: BoxDecoration(border: Border(top: rule)), child: small('DraconDex', '1')),
    ]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (word)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Navigation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                for (final n in _shown) Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: context.ddx.textMuted)),
              ],
            ),
          ),
        if (toc) ...[
          _paper(ratio: ratio, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final (i, n) in _shown.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                decoration: BoxDecoration(border: Border(bottom: rule)),
                child: Row(children: [Expanded(child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis)), Text('${i + 2}')]),
              ),
            if (_more != null) Text(_more!, style: TextStyle(color: _ink.withValues(alpha: .6))),
          ]),
          const SizedBox(height: 10),
        ],
        page,
      ],
    );
  }

  Widget _book(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 104,
        height: 156,
        padding: const EdgeInsets.all(10),
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C2D12), Color(0xFF1E1B4B)]),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(6)),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Text(title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, n) in _shown.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${i + 1}. $n', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.ddx.textMuted)),
              ),
            if (_more != null) Text(_more!, style: TextStyle(fontSize: 11, color: context.ddx.textMuted)),
          ],
        ),
      ),
    ],
  );

  Widget _sheet(BuildContext context) {
    const line = BorderSide(color: Color(0xFFD4D4D4));
    Widget cell(Widget child, {Color? bg, double? w}) => Container(
      width: w,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: bg ?? Colors.white, border: const Border(right: line, bottom: line)),
      child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 11, color: _ink), child: child),
    );
    Widget bar([double f = 1]) => FractionallySizedBox(widthFactor: f, child: Container(height: 5, color: _ink.withValues(alpha: .2)));
    const head = Color(0xFFF3F3F3), hdr = Color(0xFFE8F0FE);
    Widget row(List<Widget> cells) => Row(children: cells);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: const BoxDecoration(border: Border(left: line, top: line)),
          child: Column(children: [
            row([cell(const SizedBox(), bg: head, w: 28), for (final c in ['A', 'B', 'C']) Expanded(child: cell(Text(c), bg: head))]),
            row([cell(const Text('1'), bg: head, w: 28), Expanded(child: cell(Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), bg: hdr)), Expanded(child: cell(const SizedBox(), bg: hdr)), Expanded(child: cell(const SizedBox(), bg: hdr))]),
            for (final (i, n) in _shown.indexed)
              row([
                cell(Text('${i + 2}'), bg: head, w: 28),
                Expanded(child: cell(Text(n, maxLines: 1, overflow: TextOverflow.ellipsis))),
                Expanded(child: cell(bar())),
                Expanded(child: cell(bar(.6))),
              ]),
          ]),
        ),
      ],
    );
  }

  /// A file tree drawn with icons — the bundled font has no box-drawing
  /// glyphs, so the desktop's ├─ lines would render as boxes offline.
  /// [plain]: the lines are the file's contents, not files.
  Widget _tree(BuildContext context, String root, List<String> lines, {bool plain = false}) {
    final muted = context.ddx.textMuted;
    const style = TextStyle(fontSize: 11.5, height: 1.5);
    Widget line(IconData? icon, String text, {double indent = 0}) => Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 14, color: muted), const SizedBox(width: 6)],
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: muted))),
      ]),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(root.endsWith('.zip') ? Icons.folder_zip_outlined : Icons.insert_drive_file_outlined, root),
          for (final l in lines)
            line(plain ? null : (l.endsWith('/') ? Icons.folder_outlined : Icons.description_outlined), l, indent: plain ? 20 : 16),
          if (_more != null) line(null, _more!, indent: 20),
        ],
      ),
    );
  }
}

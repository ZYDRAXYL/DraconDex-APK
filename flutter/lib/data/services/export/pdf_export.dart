import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'doc_model.dart';
import 'doc_source.dart';

/// PDF on the phone (Procress 14, APP docs/EXPORT-DECOR.md E1). The desktop
/// prints its own drawn pages; the phone lays out the document shape — the
/// one DOCX and HTML write — with the `pdf` package, and `printing` hands it
/// to the system print or share sheet.
///
/// Thai is the default UI language and NotoSans has no Thai glyphs, so the
/// vendored Noto Sans Thai is every style's fallback font: without it a Thai
/// page prints as empty boxes.
const pdfPictureFormats = {'png', 'jpg', 'gif', 'webp'};

class PdfFonts {
  final pw.Font base, bold;
  final List<pw.Font> fallback;
  const PdfFonts(this.base, this.bold, [this.fallback = const []]);
}

class PdfOptions {
  final String paper; // A4 · Letter · A5
  final bool landscape, headerFooter, toc;
  const PdfOptions({this.paper = 'A4', this.landscape = false, this.headerFooter = true, this.toc = true});

  PdfPageFormat get format {
    final f = switch (paper) {
      'Letter' => PdfPageFormat.letter,
      'A5' => PdfPageFormat.a5,
      _ => PdfPageFormat.a4,
    };
    return landscape ? f.landscape : f.portrait;
  }
}

const _ink = PdfColor.fromInt(0xff1d1d24);
const _quiet = PdfColor.fromInt(0xff5b5b66);
const _rule = PdfColor.fromInt(0xffd6d6e0);
const _link = PdfColor.fromInt(0xff0563c1);

/// NotoSans has no ballot boxes or check marks (a task list's ☐/☑, a
/// checkbox field's ✓/✗), and a missing glyph prints as nothing at all.
String _glyphs(String s) => s.replaceAll('☐', '[ ]').replaceAll('☑', '[x]').replaceAll('✓', '[x]').replaceAll('✗', '[ ]');

pw.InlineSpan _span(Run r) {
  if (r.br) return const pw.TextSpan(text: '\n');
  final style = pw.TextStyle(
    fontWeight: r.b ? pw.FontWeight.bold : null,
    fontStyle: r.i ? pw.FontStyle.italic : null,
    decoration: r.u || r.href != null
        ? pw.TextDecoration.underline
        : r.s
        ? pw.TextDecoration.lineThrough
        : null,
    color: r.href != null ? _link : null,
    font: r.code ? pw.Font.courier() : null,
  );
  return pw.TextSpan(text: _glyphs(r.text), style: style, annotation: r.href != null ? pw.AnnotationUrl(r.href!) : null);
}

pw.Widget _rich(List<Run> runs, {pw.TextStyle? style}) => pw.RichText(
  text: pw.TextSpan(style: style, children: runs.map(_span).toList()),
);

List<pw.Widget> _blocks(List<DocBlock> blocks) => [
  for (final b in blocks)
    switch (b.t) {
      BlockKind.h => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: _rich(
          b.runs,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: const [18.0, 15.0, 13.0, 12.0][(b.level - 1).clamp(0, 3)]),
        ),
      ),
      BlockKind.p => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: _rich(b.runs)),
      BlockKind.li => pw.Padding(
        padding: pw.EdgeInsets.only(left: 14.0 * b.depth, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 16, child: pw.Text(b.ordered ? '${b.n}.' : const ['•', '–', '·'][b.depth % 3])),
            pw.Expanded(child: _rich(b.runs)),
          ],
        ),
      ),
      BlockKind.quote => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.only(left: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _rule, width: 2)),
        ),
        child: _rich(b.runs, style: const pw.TextStyle(color: _quiet)),
      ),
      BlockKind.code => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(8),
        color: const PdfColor.fromInt(0xfff0f0f4),
        child: pw.Text(b.text, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9)),
      ),
      BlockKind.hr => pw.Divider(color: _rule, thickness: .6),
      BlockKind.pagebreak => pw.NewPage(),
    },
];

/// Records the page it lands on — how the contents page learns where each
/// section starts (the package's TableOfContent only sees headers laid out
/// before it, so it cannot list what follows it).
class _Mark extends pw.StatelessWidget {
  _Mark(this.onPage);
  final void Function(int) onPage;
  @override
  pw.Widget build(pw.Context context) {
    onPage(context.pageNumber);
    return pw.SizedBox();
  }
}

/// → the PDF's bytes. [pictures]: loadMedia(…, pdfPictureFormats).
///
/// A contents page takes two layouts: the first, without it, finds the page
/// each section starts on; the contents alone tells how many pages it adds;
/// the last lays out the real thing with those numbers.
Future<Uint8List> buildPdf(ModuleDocument doc, Map<int, MediaBytes> pictures, PdfFonts fonts, PdfOptions opts) async {
  if (!opts.toc || doc.sections.length < 2) return (await _layout(doc, pictures, fonts, opts)).save();
  final starts = <int, int>{};
  await (await _layout(doc, pictures, fonts, opts, marks: starts, reserveToc: true)).save();
  final tocOnly = <int, int>{};
  await (await _layout(doc, pictures, fonts, opts, tocPages: [for (final _ in doc.sections) 0], tocOnlyEnd: tocOnly)).save();
  // the pages the contents itself fills: where it ends, less where the
  // title and intro ended
  final added = (tocOnly[-1] ?? 2) - (tocOnly[-2] ?? 1);
  return (await _layout(
    doc,
    pictures,
    fonts,
    opts,
    tocPages: [for (var i = 0; i < doc.sections.length; i++) (starts[i] ?? 0) + added],
  )).save();
}

Future<pw.Document> _layout(
  ModuleDocument doc,
  Map<int, MediaBytes> pictures,
  PdfFonts fonts,
  PdfOptions opts, {
  Map<int, int>? marks,
  bool reserveToc = false,
  List<int>? tocPages,
  Map<int, int>? tocOnlyEnd,
}) async {
  // No italic face is shipped: italic draws upright rather than falling back
  // to Helvetica-Oblique, which has no Unicode at all.
  final theme =
      pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
        italic: fonts.base,
        boldItalic: fonts.bold,
        fontFallback: fonts.fallback,
      ).copyWith(
        defaultTextStyle: pw.TextStyle(
          font: fonts.base,
          fontBold: fonts.bold,
          fontItalic: fonts.base,
          fontBoldItalic: fonts.bold,
          fontFallback: fonts.fallback,
          fontSize: 10.5,
          lineSpacing: 2,
          color: _ink,
        ),
      );
  final pdf = pw.Document(title: doc.title, creator: 'DraconDex', theme: theme);
  final imageCache = <int, pw.ImageProvider?>{};
  pw.ImageProvider? image(int id) => imageCache.putIfAbsent(id, () {
    final b = pictures[id];
    if (b == null) return null;
    try {
      return pw.MemoryImage(b.data);
    } catch (_) {
      return null;
    }
  });
  List<pw.Widget> figs(Iterable<int> ids, {double maxHeight = 260}) => [
    for (final id in ids)
      if (image(id) case final img?)
        pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Image(img, fit: pw.BoxFit.contain, height: maxHeight),
        ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: opts.format.applyMargin(
        left: 2 * PdfPageFormat.cm,
        top: 2 * PdfPageFormat.cm,
        right: 2 * PdfPageFormat.cm,
        bottom: 2 * PdfPageFormat.cm,
      ),
      maxPages: 2000,
      header: opts.headerFooter
          ? (ctx) => ctx.pageNumber == 1
                ? pw.SizedBox()
                : pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text(doc.title, style: const pw.TextStyle(fontSize: 8, color: _quiet)),
                  )
          : null,
      footer: opts.headerFooter
          ? (ctx) => pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _quiet)),
            )
          : null,
      build: (ctx) => [
        // text:, not child: — with a child every outline entry points at the
        // last page (pdf 3.12).
        pw.Header(
          level: 0,
          text: doc.title,
          textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          decoration: const pw.BoxDecoration(),
          padding: const pw.EdgeInsets.only(bottom: 8),
        ),
        if (doc.cover != null) ...figs([doc.cover!], maxHeight: 300),
        ...figs(doc.introImages),
        ..._blocks(doc.introBlocks),
        if (reserveToc) pw.NewPage(),
        if (tocPages != null) ...[
          if (tocOnlyEnd != null) _Mark((p) => tocOnlyEnd[-2] = p),
          pw.NewPage(),
          for (var i = 0; i < doc.sections.length; i++)
            pw.Link(
              destination: 's$i',
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(_glyphs(doc.sections[i].title), maxLines: 1)),
                    pw.SizedBox(width: 12),
                    pw.Text('${tocPages[i]}', style: const pw.TextStyle(color: _quiet)),
                  ],
                ),
              ),
            ),
          if (tocOnlyEnd != null) _Mark((p) => tocOnlyEnd[-1] = p),
          if (tocOnlyEnd == null) pw.NewPage(),
        ],
        if (tocOnlyEnd == null)
          for (final (i, s) in doc.sections.indexed) ...[
            if (s.breakBefore) pw.NewPage(),
            if (marks != null) _Mark((p) => marks[i] = p),
            pw.Anchor(
              name: 's$i',
              child: pw.Header(
                level: 1,
                text: _glyphs(s.title),
                textStyle: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _rule, width: .6)),
                ),
                padding: const pw.EdgeInsets.only(top: 12, bottom: 3),
              ),
            ),
            if (s.sub != null && s.sub!.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(s.sub!, style: const pw.TextStyle(color: _quiet)),
              ),
            ...figs(s.images),
            if (s.props.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Table(
                  columnWidths: {0: const pw.FractionColumnWidth(.32), 1: const pw.FractionColumnWidth(.68)},
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: _rule, width: .5),
                    bottom: pw.BorderSide(color: _rule, width: .5),
                  ),
                  children: [
                    for (final (k, v) in s.props)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_glyphs(v))),
                        ],
                      ),
                  ],
                ),
              ),
            ..._blocks(s.blocks),
          ],
      ],
    ),
  );
  return pdf;
}

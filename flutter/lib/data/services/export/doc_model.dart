/// One small document model for DOCX, EPUB, HTML and PDF — the port of EXE
/// db/doc-model.js (Procress 14, APP docs/EXPORT-DECOR.md E2/E5).
///
/// A chapter is Markdown (the app's own subset) or the HTML the desktop's
/// Author editor writes. Both are read into the same blocks here, and each
/// writer handles the handful of block kinds rather than two input languages.
///
/// Like the app's Markdown, a single newline inside a paragraph is a line
/// break. `[[Wikilink|alias]]` becomes its text: a link to a page the file
/// does not hold would go nowhere.
library;

class Run {
  final String text;
  final bool b, i, u, s, code, br;
  final String? href;
  const Run(this.text, {this.b = false, this.i = false, this.u = false, this.s = false, this.code = false, this.href}) : br = false;
  const Run.br() : text = '', b = false, i = false, u = false, s = false, code = false, br = true, href = null;

  Run copyWith({bool? b, bool? i, bool? u, bool? s, bool? code, String? href}) =>
      Run(text, b: b ?? this.b, i: i ?? this.i, u: u ?? this.u, s: s ?? this.s, code: code ?? this.code, href: href ?? this.href);
}

enum BlockKind { h, p, li, quote, code, hr, pagebreak }

class DocBlock {
  final BlockKind t;
  final int level; // h
  final bool ordered; // li
  final int depth, n; // li
  final List<Run> runs;
  final String text; // code
  const DocBlock(this.t, {this.level = 0, this.ordered = false, this.depth = 0, this.n = 0, this.runs = const [], this.text = ''});
}

final _wiki = RegExp(r'\[\[([^[\]|]+?)(?:\|([^[\]]+?))?\]\]');

// ── Markdown → blocks ───────────────────────────────────────────────────
final _inline = RegExp(
  r'`([^`\n]+)`|\[([^\]\n]+)\]\((https?://[^)\s]+)\)|\*\*([^*\n]+)\*\*|~~([^~\n]+)~~|(?:^|(?<=[^*\w]))\*([^*\n]+)\*(?!\*)|(?:^|(?<=\W))_([^_\n]+)_(?!\w)',
);

List<Run> inlineRuns(String text) {
  final src = text.replaceAllMapped(_wiki, (m) => (m[2] ?? m[1]!).trim());
  final runs = <Run>[];
  var at = 0;
  for (final m in _inline.allMatches(src)) {
    if (m.start > at) runs.add(Run(src.substring(at, m.start)));
    if (m[1] != null) {
      runs.add(Run(m[1]!, code: true));
    } else if (m[2] != null) {
      runs.add(Run(m[2]!, href: m[3]));
    } else if (m[4] != null) {
      runs.addAll(inlineRuns(m[4]!).map((r) => r.copyWith(b: true)));
    } else if (m[5] != null) {
      runs.add(Run(m[5]!, s: true));
    } else {
      runs.addAll(inlineRuns(m[6] ?? m[7]!).map((r) => r.copyWith(i: true)));
    }
    at = m.end;
  }
  if (at < src.length) runs.add(Run(src.substring(at)));
  return runs.where((r) => r.br || r.text.isNotEmpty).toList();
}

List<Run> _withBreaks(List<String> lines) => [
  for (var i = 0; i < lines.length; i++) ...[if (i > 0) const Run.br(), ...inlineRuns(lines[i])],
];

final _fence = RegExp(r'^\s*```');
final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _rule = RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$');
final _quote = RegExp(r'^>\s?(.*)$');
final _item = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(?:\[( |x|X)\]\s+)?(.*)$');

List<DocBlock> fromMarkdown(String? md) {
  final lines = (md ?? '').replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  final out = <DocBlock>[];
  var para = <String>[];
  void flush() {
    if (para.isNotEmpty) out.add(DocBlock(BlockKind.p, runs: _withBreaks(para)));
    para = [];
  }

  var counters = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_fence.hasMatch(line)) {
      flush();
      final buf = <String>[];
      while (++i < lines.length && !_fence.hasMatch(lines[i])) {
        buf.add(lines[i]);
      }
      out.add(DocBlock(BlockKind.code, text: buf.join('\n')));
      continue;
    }
    if (line.trim().isEmpty) {
      flush();
      counters = [];
      continue;
    }
    RegExpMatch? m;
    if ((m = _heading.firstMatch(line)) != null) {
      flush();
      out.add(DocBlock(BlockKind.h, level: m![1]!.length, runs: inlineRuns(m[2]!)));
      continue;
    }
    if (_rule.hasMatch(line)) {
      flush();
      out.add(const DocBlock(BlockKind.hr));
      continue;
    }
    if ((m = _quote.firstMatch(line)) != null) {
      flush();
      final buf = [m![1]!];
      while (i + 1 < lines.length && lines[i + 1].startsWith('>')) {
        buf.add(lines[++i].replaceFirst(RegExp(r'^>\s?'), ''));
      }
      out.add(DocBlock(BlockKind.quote, runs: _withBreaks(buf)));
      continue;
    }
    if ((m = _item.firstMatch(line)) != null) {
      flush();
      final depth = (m![1]!.replaceAll('\t', '  ').length ~/ 2).clamp(0, 4);
      final ordered = RegExp(r'\d').hasMatch(m[2]!);
      counters = counters.length > depth + 1 ? counters.sublist(0, depth + 1) : counters;
      while (counters.length <= depth) {
        counters.add(0);
      }
      counters[depth] = ordered ? counters[depth] + 1 : 0;
      final task = m[3] != null ? [Run(m[3] == ' ' ? '☐ ' : '☑ ')] : <Run>[];
      out.add(DocBlock(BlockKind.li, ordered: ordered, depth: depth, n: counters[depth], runs: [...task, ...inlineRuns(m[4]!)]));
      continue;
    }
    para.add(line);
  }
  flush();
  return out;
}

// ── HTML (the desktop Author editor's) → blocks ─────────────────────────
const _ent = {
  'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'emsp': ' ', 'ensp': ' ', 'thinsp': ' ', //
  'hellip': '…', 'mdash': '—', 'ndash': '–', 'lsquo': '‘', 'rsquo': '’', 'ldquo': '“', 'rdquo': '”',
};

String decodeEntities(String s) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);', caseSensitive: false), (m) {
  final e = m[1]!;
  if (e.startsWith('#')) {
    final cp = e[1] == 'x' || e[1] == 'X' ? int.tryParse(e.substring(2), radix: 16) : int.tryParse(e.substring(1));
    return cp != null && cp > 0 && cp <= 0x10ffff ? String.fromCharCode(cp) : '';
  }
  return _ent[e.toLowerCase()] ?? m[0]!;
});

const _blockTags = {'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'pre', 'section', 'article'};
const _styleTags = {'b': 'b', 'strong': 'b', 'i': 'i', 'em': 'i', 'u': 'u', 's': 's', 'strike': 's', 'del': 's', 'code': 'code'};

class _Open {
  final BlockKind t;
  final int level, depth, n;
  final bool ordered;
  final runs = <Run>[];
  _Open(this.t, {this.level = 0, this.depth = 0, this.n = 0, this.ordered = false});
}

class _List {
  final bool ordered;
  int n = 0;
  _List(this.ordered);
}

List<DocBlock> fromHtml(String? html) {
  final out = <DocBlock>[];
  final style = {'b': 0, 'i': 0, 'u': 0, 's': 0, 'code': 0};
  final lists = <_List>[];
  _Open? cur;
  String? href;
  var pre = false;

  void close() {
    final c = cur;
    if (c == null) return;
    while (c.runs.isNotEmpty && c.runs.last.br) {
      c.runs.removeLast();
    }
    if (c.t == BlockKind.code) {
      out.add(DocBlock(BlockKind.code, text: c.runs.map((r) => r.br ? '\n' : r.text).join()));
    } else if (c.runs.any((r) => r.text.trim().isNotEmpty)) {
      out.add(DocBlock(c.t, level: c.level, depth: c.depth, n: c.n, ordered: c.ordered, runs: List.of(c.runs)));
    }
    cur = null;
  }

  void open(BlockKind t, {int level = 0, int depth = 0, int n = 0, bool ordered = false}) {
    close();
    cur = _Open(t, level: level, depth: depth, n: n, ordered: ordered);
  }

  void openParaOrItem() =>
      lists.isEmpty ? open(BlockKind.p) : open(BlockKind.li, ordered: lists.last.ordered, depth: lists.length - 1, n: lists.last.n);

  void text(String s) {
    var v = decodeEntities(s);
    if (!pre) v = v.replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
    if (v.isEmpty) return;
    if (cur == null) {
      if (v.trim().isEmpty) return;
      openParaOrItem();
    }
    cur!.runs.add(
      Run(v, b: style['b']! > 0, i: style['i']! > 0, u: style['u']! > 0, s: style['s']! > 0, code: style['code']! > 0, href: href),
    );
  }

  final re = RegExp(r'<!--[\s\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>|([^<]+)');
  for (final m in re.allMatches(html ?? '')) {
    if (m[4] != null) {
      text(m[4]!);
      continue;
    }
    if (m[2] == null) continue;
    final end = m[1] == '/';
    final tag = m[2]!.toLowerCase();
    final k = _styleTags[tag];
    if (k != null) {
      style[k] = (style[k]! + (end ? -1 : 1)).clamp(0, 1 << 20);
      continue;
    }
    if (tag == 'a') {
      final h = RegExp(r'\bhref\s*=\s*"(https?://[^"]+)"', caseSensitive: false).firstMatch(m[3] ?? '');
      href = end ? null : (h != null ? decodeEntities(h[1]!) : null);
      continue;
    }
    if (tag == 'br') {
      cur?.runs.add(const Run.br());
      continue;
    }
    if (tag == 'hr') {
      close();
      out.add(const DocBlock(BlockKind.hr));
      continue;
    }
    if (tag == 'ul' || tag == 'ol') {
      close();
      if (end) {
        if (lists.isNotEmpty) lists.removeLast();
      } else {
        lists.add(_List(tag == 'ol'));
      }
      continue;
    }
    if (tag == 'pre') {
      if (end) {
        close();
        pre = false;
      } else {
        open(BlockKind.code);
        pre = true;
      }
      continue;
    }
    if (!_blockTags.contains(tag)) continue;
    if (end) {
      if (!pre) close();
      continue;
    }
    if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
      open(BlockKind.h, level: int.parse(tag[1]));
    } else if (tag == 'li') {
      final l = lists.isEmpty ? null : lists.last;
      if (l != null) l.n++;
      open(BlockKind.li, ordered: l?.ordered ?? false, depth: lists.isEmpty ? 0 : lists.length - 1, n: l?.n ?? 0);
    } else if (tag == 'blockquote') {
      open(BlockKind.quote);
    } else if (!pre) {
      openParaOrItem();
    }
  }
  close();
  return out;
}

/// The Author rule: content that starts with a tag is the editor's HTML,
/// anything else is Markdown.
List<DocBlock> toBlocks(String? content) => RegExp(r'^\s*<').hasMatch(content ?? '') ? fromHtml(content) : fromMarkdown(content);

// ── blocks → XHTML (EPUB, HTML) ─────────────────────────────────────────
String xesc(Object? s) => '${s ?? ''}'
    .replaceAll(RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]'), '')
    .replaceAllMapped(RegExp(r'[&<>"]'), (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[m[0]]!);

String runsXhtml(List<Run> runs) => runs.map((r) {
  if (r.br) return '<br/>';
  var h = xesc(r.text);
  if (r.code) h = '<code>$h</code>';
  if (r.s) h = '<del>$h</del>';
  if (r.u) h = '<u>$h</u>';
  if (r.i) h = '<em>$h</em>';
  if (r.b) h = '<strong>$h</strong>';
  if (r.href != null) h = '<a href="${xesc(r.href)}">$h</a>';
  return h;
}).join();

String toXhtml(List<DocBlock> blocks) {
  final out = <String>[];
  String? list;
  void endList() {
    if (list != null) {
      out.add('</$list>');
      list = null;
    }
  }

  for (final b in blocks) {
    if (b.t == BlockKind.li) {
      final tag = b.ordered ? 'ol' : 'ul';
      if (list != tag) {
        endList();
        out.add('<$tag>');
        list = tag;
      }
      out.add('<li${b.depth > 0 ? ' class="d${b.depth}"' : ''}>${runsXhtml(b.runs)}</li>');
      continue;
    }
    endList();
    final h = (b.level + 1).clamp(1, 6);
    switch (b.t) {
      case BlockKind.h:
        out.add('<h$h>${runsXhtml(b.runs)}</h$h>');
      case BlockKind.p:
        out.add('<p>${runsXhtml(b.runs)}</p>');
      case BlockKind.quote:
        out.add('<blockquote><p>${runsXhtml(b.runs)}</p></blockquote>');
      case BlockKind.code:
        out.add('<pre><code>${xesc(b.text)}</code></pre>');
      case BlockKind.hr:
        out.add('<hr/>');
      default:
        break;
    }
  }
  endList();
  return out.join('\n');
}

// ── blocks → WordprocessingML (DOCX) ────────────────────────────────────
/// Links need a relationship id; the DOCX writer hands one out.
abstract class DocxLinks {
  String link(String href);
}

String runsDocx(List<Run> runs, DocxLinks? ctx) => runs.map((r) {
  if (r.br) return '<w:r><w:br/></w:r>';
  final pr = [
    if (r.b) '<w:b/>',
    if (r.i) '<w:i/>',
    if (r.u) '<w:u w:val="single"/>',
    if (r.s) '<w:strike/>',
    if (r.code) '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>',
    if (r.href != null) '<w:color w:val="0563C1"/><w:u w:val="single"/>',
  ].join();
  final run = '<w:r>${pr.isNotEmpty ? '<w:rPr>$pr</w:rPr>' : ''}<w:t xml:space="preserve">${xesc(r.text)}</w:t></w:r>';
  return r.href != null && ctx != null ? '<w:hyperlink r:id="${ctx.link(r.href!)}">$run</w:hyperlink>' : run;
}).join();

String _para(String style, String body, [String extra = '']) =>
    '<w:p><w:pPr>${style.isNotEmpty ? '<w:pStyle w:val="$style"/>' : ''}$extra</w:pPr>$body</w:p>';

/// A list item is a paragraph with its bullet or number written in and a
/// hanging indent — the one list shape every word processor shows the same
/// without a numbering part.
String toDocx(List<DocBlock> blocks, DocxLinks? ctx) => blocks.map((b) {
  switch (b.t) {
    case BlockKind.h:
      return _para('Heading${(b.level + 1).clamp(1, 3)}', runsDocx(b.runs, ctx));
    case BlockKind.p:
      return _para('', runsDocx(b.runs, ctx));
    case BlockKind.quote:
      return _para('Quote', runsDocx(b.runs, ctx));
    case BlockKind.li:
      final left = 360 * (b.depth + 1);
      final mark = b.ordered ? '${b.n}.' : const ['•', '◦', '▪'][b.depth % 3];
      return _para(
        '',
        '<w:r><w:t xml:space="preserve">$mark\t</w:t></w:r>${runsDocx(b.runs, ctx)}',
        '<w:tabs><w:tab w:val="left" w:pos="$left"/></w:tabs><w:ind w:left="$left" w:hanging="360"/>',
      );
    case BlockKind.code:
      return b.text.split('\n').map((l) => _para('Code', '<w:r><w:t xml:space="preserve">${xesc(l)}</w:t></w:r>')).join();
    case BlockKind.hr:
      return _para('', '', '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="auto"/></w:pBdr>');
    case BlockKind.pagebreak:
      return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  }
}).join();

/// The words of some runs, as plain text (a PDF outline, a file name).
String plainText(List<Run> runs) => runs.map((r) => r.br ? '\n' : r.text).join();

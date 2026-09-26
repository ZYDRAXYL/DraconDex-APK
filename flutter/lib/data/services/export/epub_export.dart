import 'dart:math';

import 'doc_model.dart';
import 'doc_source.dart';
import 'zip_writer.dart';

/// EPUB 3 — an Author book; the port of EXE db/epub-export.js (Procress 14,
/// APP docs/EXPORT-DECOR.md E5). For Apple Books, Calibre, Kindle (Send to
/// Kindle takes EPUB) and Sigil. The container rules readers are strict
/// about:
///   - `mimetype` is the FIRST entry and STORED, not deflated (OCF §4.3)
///   - META-INF/container.xml points at the package document
///   - the package has a dcterms:modified, a unique identifier and a nav
/// One XHTML file per chapter; the cover is the book page's title cover.
const epubPictureFormats = {'png', 'jpg', 'gif', 'webp', 'svg'};

const _css = '''body{font-family:serif;line-height:1.6;margin:0 5%}
h1{font-size:1.6em;margin:1.5em 0 1em;text-align:center}
h2,h3,h4{margin:1.2em 0 .5em}
p{margin:0 0 .8em;text-indent:0}
blockquote{margin:1em 2em;font-style:italic}
pre{white-space:pre-wrap;font-size:.9em}
li.d1{margin-left:1.5em} li.d2{margin-left:3em} li.d3{margin-left:4.5em}
.sub{text-align:center;font-style:italic;color:#666}
figure{margin:1em 0;text-align:center} figure img{max-width:100%}
.cover{text-align:center;margin:0} .cover img{max-width:100%;max-height:100vh}''';

String _page(String title, String lang, String body) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="$lang" lang="$lang">
<head><meta charset="UTF-8"/><title>${xesc(title)}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>$body</body>
</html>''';

String _uuid(Random r) {
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// → zip entries; null when the document is not a book, empty when it has
/// no chapters.
List<ZipEntry>? epubEntries(ModuleDocument doc, Map<int, MediaBytes> pictures, {String lang = 'en', DateTime? now}) {
  if (doc.kind != 'author') return null;
  if (doc.sections.isEmpty) return const [];
  final lg = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]+)?$').hasMatch(lang) ? lang : 'en';
  final id = 'urn:uuid:${_uuid(Random.secure())}';
  final modified = '${(now ?? DateTime.now()).toUtc().toIso8601String().split('.').first}Z';
  final manifest = <String>[];
  final spine = <String>[];
  final files = <ZipEntry>[];
  final hrefs = <int, String?>{};
  String? picture(int fileId, {bool cover = false}) => hrefs.putIfAbsent(fileId, () {
    final b = pictures[fileId];
    if (b == null) return null;
    final n = hrefs.values.whereType<String>().length + 1;
    final href = 'images/img$n.${b.ext}';
    files.add(ZipEntry('OEBPS/$href', b.data));
    manifest.add('<item id="img$n" href="$href" media-type="${b.mime}"${cover ? ' properties="cover-image"' : ''}/>');
    return href;
  });

  final coverHref = doc.cover != null ? picture(doc.cover!, cover: true) : null;
  if (coverHref != null) {
    files.add(
      ZipEntry(
        'OEBPS/cover.xhtml',
        _page(doc.title, lg, '<section class="cover" epub:type="cover"><img src="$coverHref" alt="${xesc(doc.title)}"/></section>'),
      ),
    );
    manifest.add('<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>');
    spine.add('<itemref idref="cover" linear="yes"/>');
  }
  String figs(List<int> list) => list.map(picture).whereType<String>().map((h) => '<figure><img src="$h" alt=""/></figure>').join();
  final width = max(3, '${doc.sections.length}'.length);
  final chapters = <({String href, String title})>[];
  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    final n = '${i + 1}'.padLeft(width, '0');
    final href = 'ch-$n.xhtml';
    files.add(
      ZipEntry(
        'OEBPS/$href',
        _page(
          s.title,
          lg,
          '<section epub:type="chapter"><h1>${xesc(s.title)}</h1>${s.sub != null && s.sub!.isNotEmpty ? '<p class="sub">${xesc(s.sub)}</p>' : ''}${figs(s.images)}\n${toXhtml(s.blocks)}</section>',
        ),
      ),
    );
    manifest.add('<item id="ch$n" href="$href" media-type="application/xhtml+xml"/>');
    spine.add('<itemref idref="ch$n"/>');
    chapters.add((href: href, title: s.title));
  }

  final nav = _page(doc.title, lg, '''<nav epub:type="toc" id="toc"><h1>${xesc(doc.title)}</h1><ol>
${chapters.map((c) => '<li><a href="${c.href}">${xesc(c.title)}</a></li>').join('\n')}
</ol></nav>''');
  final opf =
      '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="$lg">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="bookid">$id</dc:identifier>
<dc:title>${xesc(doc.title)}</dc:title>
<dc:language>$lg</dc:language>
<meta property="dcterms:modified">$modified</meta>
</metadata>
<manifest>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
<item id="css" href="style.css" media-type="text/css"/>
${manifest.join('\n')}
</manifest>
<spine>
${spine.join('\n')}
</spine>
</package>''';
  return [
    ZipEntry('mimetype', 'application/epub+zip', store: true),
    ZipEntry('META-INF/container.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
    ZipEntry('OEBPS/content.opf', opf),
    ZipEntry('OEBPS/nav.xhtml', nav),
    ZipEntry('OEBPS/style.css', _css),
    ...files,
  ];
}

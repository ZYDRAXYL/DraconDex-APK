import 'doc_model.dart';
import 'doc_source.dart';
import 'zip_writer.dart';

/// The page as a web page (Procress 14, APP docs/EXPORT-DECOR.md E7 on the
/// phone). The desktop draws a site of pages through its own components;
/// the phone writes the document shape instead — the same one DOCX and the
/// PDF use — as one self-contained index.html, its pictures in media/,
/// zipped so the folder opens in any browser as it is.
const htmlPictureFormats = {'png', 'jpg', 'gif', 'webp', 'svg'};

const _css = '''*{box-sizing:border-box}
body{font:16px/1.6 system-ui,-apple-system,"Segoe UI","Noto Sans","Noto Sans Thai",sans-serif;color:#1d1d24;background:#fafafa;margin:0}
main{max-width:46rem;margin:0 auto;padding:2rem 1rem 4rem}
h1{font-size:2rem;line-height:1.2;margin:0 0 1rem}
h2{font-size:1.4rem;margin:2.2rem 0 .4rem;padding-top:1rem;border-top:1px solid #e3e3ea}
h3,h4,h5,h6{margin:1.4rem 0 .4rem}
.sub{color:#5b5b66;font-style:italic;margin:0 0 .8rem}
figure{margin:1rem 0;text-align:center} figure img{max-width:100%;height:auto;border-radius:6px}
.cover img{width:100%;max-height:22rem;object-fit:cover;border-radius:8px}
table.props{border-collapse:collapse;width:100%;margin:.6rem 0 1rem}
table.props th,table.props td{border-bottom:1px solid #e3e3ea;padding:.35rem .5rem;text-align:left;vertical-align:top}
table.props th{width:32%;color:#44444f;font-weight:600}
blockquote{margin:1rem 0;padding:.2rem 1rem;border-left:3px solid #c9c9d6;color:#44444f}
pre{background:#f0f0f4;padding:.8rem;border-radius:6px;white-space:pre-wrap}
li.d1{margin-left:1.5em} li.d2{margin-left:3em} li.d3{margin-left:4.5em}
nav.toc ol{padding-left:1.2rem}
@media (prefers-color-scheme:dark){body{background:#131318;color:#ececf2}h2{border-color:#2c2c36}
.sub,blockquote,table.props th{color:#b4b4c0}table.props th,table.props td{border-color:#2c2c36}pre{background:#1e1e26}a{color:#8fb4ff}}''';

/// → zip entries: index.html, style.css and media/.
List<ZipEntry> htmlEntries(ModuleDocument doc, Map<int, MediaBytes> pictures, {String lang = 'en'}) {
  final media = <ZipEntry>[];
  final hrefs = <int, String?>{};
  String? pic(int id) => hrefs.putIfAbsent(id, () {
    final b = pictures[id];
    if (b == null) return null;
    final href = 'media/${media.length + 1}.${b.ext}';
    media.add(ZipEntry(href, b.data));
    return href;
  });
  String figs(Iterable<int> ids) => ids.map(pic).whereType<String>().map((h) => '<figure><img src="$h" alt=""></figure>').join();

  final body = StringBuffer('<h1>${xesc(doc.title)}</h1>');
  final cover = doc.cover != null ? pic(doc.cover!) : null;
  if (cover != null) body.write('<figure class="cover"><img src="$cover" alt=""></figure>');
  body.write(figs(doc.introImages));
  body.write(toXhtml(doc.introBlocks));
  if (doc.sections.length > 1) {
    body.write(
      '<nav class="toc"><ol>${[for (var i = 0; i < doc.sections.length; i++) '<li><a href="#s${i + 1}">${xesc(doc.sections[i].title)}</a></li>'].join()}</ol></nav>',
    );
  }
  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    body.write('<section><h2 id="s${i + 1}">${xesc(s.title)}</h2>');
    if (s.sub != null && s.sub!.isNotEmpty) body.write('<p class="sub">${xesc(s.sub)}</p>');
    body.write(figs(s.images));
    if (s.props.isNotEmpty) {
      body.write('<table class="props">${s.props.map((p) => '<tr><th>${xesc(p.$1)}</th><td>${xesc(p.$2)}</td></tr>').join()}</table>');
    }
    body.write(toXhtml(s.blocks));
    body.write('</section>');
  }
  final lg = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]+)?$').hasMatch(lang) ? lang : 'en';
  final html =
      '''<!doctype html>
<html lang="$lg"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${xesc(doc.title)}</title><link rel="stylesheet" href="style.css"></head>
<body><main>$body</main></body></html>
''';
  return [ZipEntry('index.html', html), ZipEntry('style.css', _css), ...media];
}

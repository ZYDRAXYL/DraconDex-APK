import 'dart:typed_data';

import 'doc_model.dart';
import 'doc_source.dart';
import 'zip_writer.dart';

/// DOCX — the port of EXE db/docx-export.js (Procress 14, APP
/// docs/EXPORT-DECOR.md E2). Office Open XML through the zip writer: Title,
/// Heading 1 per section (Word's Navigation pane lists them), a property
/// table, the page's pictures, the text, a page break between chapters,
/// links to the web as real hyperlinks.
///
/// Pixel size from the file's own header (PNG, JPEG, GIF, WebP) — a picture
/// with no readable size is placed at a square default.
({int w, int h})? imageSize(Uint8List b) {
  try {
    final d = ByteData.sublistView(b);
    if (b.length > 24 && d.getUint32(0) == 0x89504e47) return (w: d.getUint32(16), h: d.getUint32(20));
    if (b.length > 10 && String.fromCharCodes(b.sublist(0, 3)) == 'GIF') {
      return (w: d.getUint16(6, Endian.little), h: d.getUint16(8, Endian.little));
    }
    if (b.length > 30 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      final kind = String.fromCharCodes(b.sublist(12, 16));
      int u24(int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
      if (kind == 'VP8X') return (w: 1 + u24(24), h: 1 + u24(27));
      if (kind == 'VP8 ') return (w: d.getUint16(26, Endian.little) & 0x3fff, h: d.getUint16(28, Endian.little) & 0x3fff);
      if (kind == 'VP8L') {
        final v = d.getUint32(21, Endian.little);
        return (w: 1 + (v & 0x3fff), h: 1 + ((v >> 14) & 0x3fff));
      }
    }
    if (b.length > 4 && b[0] == 0xff && b[1] == 0xd8) {
      for (var i = 2; i + 9 < b.length;) {
        if (b[i] != 0xff) {
          i++;
          continue;
        }
        final marker = b[i + 1];
        final len = d.getUint16(i + 2);
        if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].contains(marker)) {
          return (w: d.getUint16(i + 7), h: d.getUint16(i + 5));
        }
        i += 2 + len;
      }
    }
  } catch (_) {}
  return null;
}

const _emuPerPx = 9525; // 96 dpi
const _maxW = 6 * 914400; // six inches: a portrait page's text width

class _Img {
  final String id;
  final int cx, cy, n;
  const _Img(this.id, this.cx, this.cy, this.n);
}

class _Ctx implements DocxLinks {
  final Map<int, MediaBytes> pictures;
  _Ctx(this.pictures);
  final rels = <({String id, String type, String target})>[];
  final media = <ZipEntry>[];
  final _byFile = <int, _Img?>{};
  final _byHref = <String, String>{};

  @override
  String link(String href) => _byHref.putIfAbsent(href, () {
    final id = 'rId${100 + rels.length}';
    rels.add((id: id, type: 'hyperlink', target: href));
    return id;
  });

  _Img? image(int fileId) => _byFile.putIfAbsent(fileId, () {
    final b = pictures[fileId];
    if (b == null) return null;
    final id = 'rId${100 + rels.length}';
    final name = 'media/image${media.length + 1}.${b.ext}';
    rels.add((id: id, type: 'image', target: name));
    media.add(ZipEntry('word/$name', b.data));
    final px = imageSize(b.data) ?? (w: 480, h: 480);
    var cx = px.w * _emuPerPx, cy = px.h * _emuPerPx;
    if (cx > _maxW) {
      cy = (cy * (_maxW / cx)).round();
      cx = _maxW;
    }
    return _Img(id, cx, cy, media.length);
  });
}

/// What a DOCX can hold: PNG, JPEG, GIF.
const docxPictureFormats = {'png', 'jpg', 'gif'};

String _picture(_Img img, String name) =>
    '''<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">
<wp:extent cx="${img.cx}" cy="${img.cy}"/><wp:docPr id="${img.n}" name="${xesc(name)}"/>
<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="${img.n}" name="${xesc(name)}"/><pic:cNvPicPr/></pic:nvPicPr>
<pic:blipFill><a:blip r:embed="${img.id}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${img.cx}" cy="${img.cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>
</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>''';

String _propsTable(List<(String, String)> props) {
  String cell(String text, int w, bool bold) =>
      '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/></w:tcPr><w:p><w:r>${bold ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${xesc(text)}</w:t></w:r></w:p></w:tc>';
  return '''<w:tbl><w:tblPr><w:tblStyle w:val="PropTable"/><w:tblW w:w="5000" w:type="pct"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="2600"/><w:gridCol w:w="6400"/></w:tblGrid>
${props.map((p) => '<w:tr>${cell(p.$1, 2600, true)}${cell(p.$2, 6400, false)}</w:tr>').join()}</w:tbl><w:p/>''';
}

String _documentXml(ModuleDocument doc, _Ctx ctx) {
  final body = <String>['<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">${xesc(doc.title)}</w:t></w:r></w:p>'];
  void pics(Iterable<int> ids, [String? name]) {
    for (final f in ids) {
      final img = ctx.image(f);
      if (img != null) body.add(_picture(img, name ?? 'image ${img.n}'));
    }
  }

  if (doc.cover != null) pics([doc.cover!], 'cover');
  pics(doc.introImages);
  body.add(toDocx(doc.introBlocks, ctx));
  for (final s in doc.sections) {
    body.add(
      '<w:p><w:pPr><w:pStyle w:val="Heading1"/>${s.breakBefore ? '<w:pageBreakBefore/>' : ''}</w:pPr><w:r><w:t xml:space="preserve">${xesc(s.title)}</w:t></w:r></w:p>',
    );
    if (s.sub != null && s.sub!.isNotEmpty) {
      body.add('<w:p><w:pPr><w:pStyle w:val="Subtitle"/></w:pPr><w:r><w:t xml:space="preserve">${xesc(s.sub)}</w:t></w:r></w:p>');
    }
    pics(s.images);
    if (s.props.isNotEmpty) body.add(_propsTable(s.props));
    body.add(toDocx(s.blocks, ctx));
  }
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
<w:body>${body.join('\n')}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body>
</w:document>''';
}

const _fonts = '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Yu Gothic" w:cs="Leelawadee UI"/>';
String _style(String id, String name, String pPr, String rPr) =>
    '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>${pPr.isNotEmpty ? '<w:pPr>$pPr</w:pPr>' : ''}<w:rPr>$rPr</w:rPr></w:style>';

final _styles =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr>$_fonts<w:sz w:val="22"/><w:szCs w:val="28"/><w:lang w:val="en-US" w:bidi="th-TH"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
${_style('Title', 'Title', '<w:spacing w:after="240"/>', '<w:sz w:val="52"/><w:szCs w:val="52"/>')}
${_style('Subtitle', 'Subtitle', '', '<w:i/><w:color w:val="666666"/>')}
${_style('Heading1', 'heading 1', '<w:keepNext/><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/>', '<w:b/><w:sz w:val="36"/><w:szCs w:val="36"/>')}
${_style('Heading2', 'heading 2', '<w:keepNext/><w:spacing w:before="240" w:after="80"/><w:outlineLvl w:val="1"/>', '<w:b/><w:sz w:val="30"/><w:szCs w:val="30"/>')}
${_style('Heading3', 'heading 3', '<w:keepNext/><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="2"/>', '<w:b/><w:sz w:val="26"/><w:szCs w:val="26"/>')}
${_style('Quote', 'Quote', '<w:ind w:left="567" w:right="567"/>', '<w:i/><w:color w:val="555555"/>')}
${_style('Code', 'Code', '<w:spacing w:after="0"/>', '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:sz w:val="20"/>')}
<w:style w:type="table" w:styleId="PropTable"><w:name w:val="Property Table"/><w:tblPr><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>
</w:tblBorders><w:tblCellMar><w:top w:w="40" w:type="dxa"/><w:left w:w="80" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
</w:styles>''';

/// [pictures]: loadMedia(…, docxPictureFormats) of the document's pictures.
List<ZipEntry> docxEntries(ModuleDocument doc, Map<int, MediaBytes> pictures, {DateTime? now}) {
  final ctx = _Ctx(pictures);
  final document = _documentXml(doc, ctx);
  final stamp = '${(now ?? DateTime.now()).toUtc().toIso8601String().split('.').first}Z';
  return [
    ZipEntry('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="gif" ContentType="image/gif"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>'''),
    ZipEntry('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>'''),
    ZipEntry('docProps/core.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:title>${xesc(doc.title)}</dc:title><dc:creator>DraconDex</dc:creator>
<dcterms:created xsi:type="dcterms:W3CDTF">$stamp</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">$stamp</dcterms:modified>
</cp:coreProperties>'''),
    ZipEntry('word/document.xml', document),
    ZipEntry('word/styles.xml', _styles),
    ZipEntry('word/_rels/document.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
${ctx.rels.map((r) => r.type == 'hyperlink' ? '<Relationship Id="${r.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${xesc(r.target)}" TargetMode="External"/>' : '<Relationship Id="${r.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="${r.target}"/>').join('\n')}
</Relationships>'''),
    ...ctx.media,
  ];
}

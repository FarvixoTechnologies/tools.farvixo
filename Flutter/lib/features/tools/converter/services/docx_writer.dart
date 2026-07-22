import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Minimal OOXML Word (.docx) writer — paragraphs + optional tables.
class DocxWriter {
  const DocxWriter();

  Uint8List build({
    required List<String> paragraphs,
    List<List<List<String>>> tables = const [],
  }) {
    final body = StringBuffer();
    for (final p in paragraphs) {
      final t = p.trim();
      if (t.isEmpty) {
        body.write('<w:p/>');
        continue;
      }
      body.write(
        '<w:p><w:r><w:t xml:space="preserve">${_xml(t)}</w:t></w:r></w:p>',
      );
    }
    for (final table in tables) {
      body.write(_tableXml(table));
    }

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
  </w:body>
</w:document>''';

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final docRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    final styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/><w:qFormat/>
  </w:style>
</w:styles>''';

    final archive = Archive();
    void add(String path, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);
    add('word/_rels/document.xml.rels', docRels);
    add('word/styles.xml', styles);

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Split extracted PDF text into paragraphs (blank-line aware).
  List<String> paragraphsFromText(String text) {
    final chunks = text
        .split(RegExp(r'\n\s*\n'))
        .map((c) => c.replaceAll(RegExp(r'[ \t]+\n'), '\n').trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (chunks.isNotEmpty) return chunks;
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  String _tableXml(List<List<String>> rows) {
    if (rows.isEmpty) return '';
    final buf = StringBuffer('<w:tbl>');
    buf.write(
      '<w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '</w:tblBorders></w:tblPr>',
    );
    for (final row in rows) {
      buf.write('<w:tr>');
      for (final cell in row) {
        buf.write(
          '<w:tc><w:tcPr><w:tcW w:w="2000" w:type="dxa"/></w:tcPr>'
          '<w:p><w:r><w:t xml:space="preserve">${_xml(cell)}</w:t></w:r></w:p></w:tc>',
        );
      }
      buf.write('</w:tr>');
    }
    buf.write('</w:tbl><w:p/>');
    return buf.toString();
  }

  String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

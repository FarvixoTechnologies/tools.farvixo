import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Minimal PPTX writer — one full-bleed JPEG image per slide.
class PptxWriter {
  const PptxWriter();

  Uint8List build(List<Uint8List> jpegSlides) {
    if (jpegSlides.isEmpty) {
      throw StateError('Need at least one slide image');
    }

    final archive = Archive();
    void addBytes(String path, List<int> data) {
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    void addXml(String path, String xml) => addBytes(path, utf8.encode(xml));

    final overrides = StringBuffer();
    final slideRels = StringBuffer();
    for (var i = 0; i < jpegSlides.length; i++) {
      final n = i + 1;
      overrides.write(
        '<Override PartName="/ppt/slides/slide$n.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
      slideRels.write(
        '<Relationship Id="rId$n" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
        'Target="slides/slide$n.xml"/>',
      );
      addBytes('ppt/media/image$n.jpg', jpegSlides[i]);
      addXml(
        'ppt/slides/_rels/slide$n.xml.rels',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$n.jpg"/>
</Relationships>''',
      );
      // EMU: 914400 per inch — 10" x 7.5" widescreen-ish slide
      addXml(
        'ppt/slides/slide$n.xml',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:pic>
        <p:nvPicPr><p:cNvPr id="2" name="Slide"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
        <p:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
        <p:spPr>
          <a:xfrm><a:off x="0" y="0"/><a:ext cx="9144000" cy="6858000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
</p:sld>''',
      );
    }

    final sldIdLst = StringBuffer();
    for (var i = 0; i < jpegSlides.length; i++) {
      sldIdLst.write(
        '<p:sldId id="${256 + i}" r:id="rId${i + 1}"/>',
      );
    }

    addXml(
      '[Content_Types].xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  $overrides
</Types>''',
    );
    addXml(
      '_rels/.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''',
    );
    addXml(
      'ppt/presentation.xml',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldIdLst>$sldIdLst</p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000"/>
</p:presentation>''',
    );
    addXml(
      'ppt/_rels/presentation.xml.rels',
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  $slideRels
</Relationships>''',
    );

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

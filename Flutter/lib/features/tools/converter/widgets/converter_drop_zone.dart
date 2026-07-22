/// Accepted input formats for the PDF Converter.
///
/// The drag-and-drop *widget* that used to live here was replaced by
/// `LightningPicker`, which renders the Lightning Upload key art and handles
/// browse, drop and validation in one place. This file keeps the format
/// contract, which is converter domain knowledge rather than upload plumbing.
///
/// Note the old widget also imported `dart:io` directly to detect the
/// platform — that is why it could never be used in a web build. `LightningPicker`
/// goes through `UploadPlatform`, which is web-safe.
library;

/// Extensions the converter can ingest — lowercase, no dots.
class ConverterFormats {
  ConverterFormats._();

  static const accepted = {
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
    'docx',
    'xlsx',
    'xls',
    'csv',
    'txt',
    'md',
    'html',
    'htm',
  };
}

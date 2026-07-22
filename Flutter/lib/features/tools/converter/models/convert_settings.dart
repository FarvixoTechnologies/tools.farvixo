/// Image export / PPTX raster settings for the PDF Converter.
class ConvertSettings {
  const ConvertSettings({
    this.imageQuality = 0.85,
    this.resolution = 2.0,
    this.zipMultiPageImages = true,
  });

  /// JPEG/WebP quality in 0.5–1.0 (ignored for PNG).
  final double imageQuality;

  /// Render scale relative to 72 DPI (1.5 / 2.0 / 3.0).
  final double resolution;

  /// When true, multi-page image exports are packed into a ZIP.
  final bool zipMultiPageImages;

  ConvertSettings copyWith({
    double? imageQuality,
    double? resolution,
    bool? zipMultiPageImages,
  }) =>
      ConvertSettings(
        imageQuality: imageQuality ?? this.imageQuality,
        resolution: resolution ?? this.resolution,
        zipMultiPageImages: zipMultiPageImages ?? this.zipMultiPageImages,
      );

  static const qualityPresets = [0.6, 0.75, 0.85, 0.95];
  static const resolutionPresets = [1.5, 2.0, 3.0];
}

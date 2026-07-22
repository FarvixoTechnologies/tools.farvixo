import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/category_colors.dart';

/// Which platform family the app is running on.
///
/// Computed once from [defaultTargetPlatform] + [kIsWeb] so source lists,
/// layouts and drag-and-drop support all agree.
enum UploadPlatform {
  android,
  ios,
  windows,
  macos,
  linux,
  web;

  static UploadPlatform get current {
    if (kIsWeb) return UploadPlatform.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return UploadPlatform.android;
      case TargetPlatform.iOS:
        return UploadPlatform.ios;
      case TargetPlatform.windows:
        return UploadPlatform.windows;
      case TargetPlatform.macOS:
        return UploadPlatform.macos;
      case TargetPlatform.linux:
        return UploadPlatform.linux;
      case TargetPlatform.fuchsia:
        return UploadPlatform.android;
    }
  }

  bool get isMobile => this == android || this == ios;
  bool get isDesktop => this == windows || this == macos || this == linux;
  bool get isWeb => this == web;

  /// Whether OS-level file drag-and-drop is available.
  bool get supportsDrop => isDesktop || isWeb || this == android;
}

/// Where a file can come from.
///
/// Each source knows which platforms it is available on, so the source sheet
/// never offers something the current device cannot do.
enum UploadSource {
  files(
    label: 'Files',
    detail: 'Browse device storage',
    icon: Icons.folder_rounded,
    group: SourceGroup.device,
  ),
  folder(
    label: 'Folder',
    detail: 'Upload an entire folder',
    icon: Icons.drive_folder_upload_rounded,
    group: SourceGroup.device,
    platforms: {
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
    },
  ),
  gallery(
    label: 'Gallery',
    detail: 'Photos and videos',
    icon: Icons.photo_library_rounded,
    group: SourceGroup.device,
    platforms: {UploadPlatform.android, UploadPlatform.ios},
  ),
  camera(
    label: 'Camera',
    detail: 'Take a photo now',
    icon: Icons.photo_camera_rounded,
    group: SourceGroup.device,
    platforms: {UploadPlatform.android, UploadPlatform.ios},
  ),
  scanner(
    label: 'Scanner',
    detail: 'Scan a document',
    icon: Icons.document_scanner_rounded,
    group: SourceGroup.device,
    platforms: {UploadPlatform.android, UploadPlatform.ios},
  ),
  clipboard(
    label: 'Clipboard',
    detail: 'Paste a file or image',
    icon: Icons.content_paste_rounded,
    group: SourceGroup.device,
  ),
  recent(
    label: 'Recent',
    detail: 'Files you used lately',
    icon: Icons.history_rounded,
    group: SourceGroup.device,
  ),
  external(
    label: 'External drive',
    detail: 'USB, SD card, NAS mount',
    icon: Icons.usb_rounded,
    group: SourceGroup.device,
    platforms: {
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
      UploadPlatform.android,
    },
  ),
  dragDrop(
    label: 'Drag & drop',
    detail: 'Drop files onto the stage',
    icon: Icons.pan_tool_alt_rounded,
    group: SourceGroup.device,
    platforms: {
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
      UploadPlatform.web,
      UploadPlatform.android,
    },
  ),

  // ---- Cloud ----
  googleDrive(
    label: 'Google Drive',
    detail: 'Import from Drive',
    icon: Icons.add_to_drive_rounded,
    group: SourceGroup.cloud,
    requiresAuth: true,
  ),
  dropbox(
    label: 'Dropbox',
    detail: 'Import from Dropbox',
    icon: Icons.cloud_rounded,
    group: SourceGroup.cloud,
    requiresAuth: true,
  ),
  oneDrive(
    label: 'OneDrive',
    detail: 'Import from OneDrive',
    icon: Icons.cloud_queue_rounded,
    group: SourceGroup.cloud,
    requiresAuth: true,
  ),
  box(
    label: 'Box',
    detail: 'Import from Box',
    icon: Icons.inbox_rounded,
    group: SourceGroup.cloud,
    requiresAuth: true,
  ),

  // ---- Network ----
  url(
    label: 'From URL',
    detail: 'Paste a direct link',
    icon: Icons.link_rounded,
    group: SourceGroup.network,
  ),
  smb(
    label: 'SMB share',
    detail: 'Windows / Samba share',
    icon: Icons.lan_rounded,
    group: SourceGroup.network,
    platforms: {
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
    },
  ),
  ftp(
    label: 'FTP / SFTP',
    detail: 'Connect to a file server',
    icon: Icons.dns_rounded,
    group: SourceGroup.network,
    platforms: {
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
    },
  );

  const UploadSource({
    required this.label,
    required this.detail,
    required this.icon,
    required this.group,
    this.platforms = const {
      UploadPlatform.android,
      UploadPlatform.ios,
      UploadPlatform.windows,
      UploadPlatform.macos,
      UploadPlatform.linux,
      UploadPlatform.web,
    },
    this.requiresAuth = false,
  });

  final String label;
  final String detail;
  final IconData icon;
  final SourceGroup group;

  /// Platforms this source can run on.
  final Set<UploadPlatform> platforms;

  /// Whether an OAuth connection is needed before this source can be used.
  ///
  /// Sources with this set render as "Connect" until credentials are supplied —
  /// see `docs/LIGHTNING_UPLOAD.md` § Blocked work.
  final bool requiresAuth;

  bool availableOn(UploadPlatform platform) => platforms.contains(platform);

  /// Sources usable on [platform], grouped in sheet order.
  static List<UploadSource> forPlatform(UploadPlatform platform) =>
      UploadSource.values.where((s) => s.availableOn(platform)).toList();
}

/// Section headings in the source sheet.
enum SourceGroup {
  device('On this device'),
  cloud('Cloud storage'),
  network('Network');

  const SourceGroup(this.label);

  final String label;

  /// Colour identity for this group's icons.
  CategoryIdentity get identity => switch (this) {
        SourceGroup.device => CategoryColors.upload,
        SourceGroup.cloud => CategoryColors.cloud,
        SourceGroup.network => CategoryColors.dev,
      };
}

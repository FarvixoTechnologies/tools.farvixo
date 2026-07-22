import 'package:flutter/material.dart';

import '../../../theme/upload_theme.dart';

/// Every state the Lightning Upload stage can be in.
///
/// The hero visual is driven entirely by this enum — each status declares its
/// own label, icon, stage tint and whether the stage should be striking,
/// spinning or resting. Adding a state therefore cannot desync the visual.
enum UploadStatus {
  /// Nothing picked yet — folder floats, ambient lightning.
  idle(
    label: 'Drop files to upload',
    icon: Icons.bolt_rounded,
    phase: StagePhase.resting,
  ),

  /// Pointer / dragged payload is over the drop zone.
  hover(
    label: 'Release to add',
    icon: Icons.file_download_rounded,
    phase: StagePhase.charging,
  ),

  /// Drop zone actively pressed.
  pressed(
    label: 'Opening…',
    icon: Icons.touch_app_rounded,
    phase: StagePhase.charging,
  ),

  /// Native picker / camera / cloud sheet is open.
  selecting(
    label: 'Choosing files',
    icon: Icons.folder_open_rounded,
    phase: StagePhase.charging,
  ),

  /// Reading metadata, sizing, building the queue.
  preparing(
    label: 'Preparing files',
    icon: Icons.inventory_2_rounded,
    phase: StagePhase.charging,
  ),

  /// Malware / policy scan before transfer.
  scanning(
    label: 'Scanning for threats',
    icon: Icons.shield_rounded,
    phase: StagePhase.working,
  ),

  /// Client-side encryption pass.
  encrypting(
    label: 'Encrypting',
    icon: Icons.lock_rounded,
    phase: StagePhase.working,
  ),

  /// Bytes on the wire — the headline state.
  uploading(
    label: 'Uploading',
    icon: Icons.rocket_launch_rounded,
    phase: StagePhase.striking,
  ),

  /// Server-side processing after the last chunk lands.
  processing(
    label: 'Processing',
    icon: Icons.settings_rounded,
    phase: StagePhase.working,
  ),

  /// AI classification / smart rename / auto-organise.
  aiOptimizing(
    label: 'AI optimising',
    icon: Icons.auto_awesome_rounded,
    phase: StagePhase.working,
  ),

  /// Lossless size reduction before or during transfer.
  compressing(
    label: 'Compressing',
    icon: Icons.compress_rounded,
    phase: StagePhase.working,
  ),

  /// Checksum comparison against the server copy.
  verifying(
    label: 'Verifying integrity',
    icon: Icons.fact_check_rounded,
    phase: StagePhase.working,
  ),

  /// Everything landed and verified.
  completed(
    label: 'Upload complete',
    icon: Icons.check_circle_rounded,
    phase: StagePhase.celebrating,
    tint: UploadPalette.success,
  ),

  /// Transfer failed — retryable.
  failed(
    label: 'Upload failed',
    icon: Icons.error_rounded,
    phase: StagePhase.faulted,
    tint: UploadPalette.failure,
  ),

  /// Automatic retry in flight.
  retrying(
    label: 'Retrying',
    icon: Icons.refresh_rounded,
    phase: StagePhase.working,
  ),

  /// User cancelled.
  cancelled(
    label: 'Cancelled',
    icon: Icons.block_rounded,
    phase: StagePhase.faulted,
    tint: UploadPalette.paused,
  ),

  /// User paused; bytes preserved.
  paused(
    label: 'Paused',
    icon: Icons.pause_circle_rounded,
    phase: StagePhase.resting,
    tint: UploadPalette.paused,
  ),

  /// Resuming from the last completed chunk.
  resuming(
    label: 'Resuming',
    icon: Icons.play_circle_rounded,
    phase: StagePhase.charging,
  ),

  /// No connection — queued until the network returns.
  offlineQueued(
    label: 'Queued — offline',
    icon: Icons.cloud_off_rounded,
    phase: StagePhase.resting,
    tint: UploadPalette.paused,
  );

  const UploadStatus({
    required this.label,
    required this.icon,
    required this.phase,
    this.tint,
  });

  final String label;
  final IconData icon;

  /// How the hero stage animates in this status.
  final StagePhase phase;

  /// Overrides the default gold stage tint (success green, failure rose, …).
  final Color? tint;

  /// Stage accent for this status.
  Color get color => tint ?? UploadPalette.bolt;

  /// Whether bytes are actively moving.
  bool get isActive => const {
        UploadStatus.scanning,
        UploadStatus.encrypting,
        UploadStatus.uploading,
        UploadStatus.processing,
        UploadStatus.aiOptimizing,
        UploadStatus.compressing,
        UploadStatus.verifying,
        UploadStatus.retrying,
        UploadStatus.resuming,
      }.contains(this);

  /// Whether the transfer has stopped for good (success or otherwise).
  bool get isTerminal => const {
        UploadStatus.completed,
        UploadStatus.failed,
        UploadStatus.cancelled,
      }.contains(this);

  /// Whether the user can pause from here.
  bool get canPause => isActive && this != UploadStatus.verifying;

  /// Whether the user can resume from here.
  bool get canResume => const {
        UploadStatus.paused,
        UploadStatus.offlineQueued,
      }.contains(this);

  /// Whether the user can retry from here.
  bool get canRetry => const {
        UploadStatus.failed,
        UploadStatus.cancelled,
      }.contains(this);

  /// Whether a determinate progress value should be shown.
  bool get showsProgress => isActive || this == UploadStatus.paused;
}

/// How the hero stage behaves for a given [UploadStatus].
enum StagePhase {
  /// Folder floats, ambient lightning every few seconds.
  resting,

  /// Ring brightens, cloud tightens — energy building.
  charging,

  /// Ring spins, arrow pulses, periodic strikes.
  working,

  /// Continuous lightning, speed lines, maximum energy.
  striking,

  /// Burst, ring fills, check draws.
  celebrating,

  /// Cloud desaturates, ring breaks, no lightning.
  faulted,
}

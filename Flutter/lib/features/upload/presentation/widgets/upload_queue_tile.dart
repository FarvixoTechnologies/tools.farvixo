import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/category_colors.dart';
import '../../../../theme/design_tokens.dart';
import '../../domain/upload_item.dart';
import '../../domain/upload_status.dart';
import '../../providers/upload_providers.dart';

/// One row in the upload queue.
///
/// Theme-aware (unlike the hero stage, which is always dark) and shows only
/// the controls legal for the item's current status.
class UploadQueueTile extends ConsumerWidget {
  const UploadQueueTile({super.key, required this.item});

  final UploadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final id = CategoryColors.upload;
    final status = item.status;
    final accent = status.tint ?? id.accentOf(context);
    final queue = ref.read(uploadQueueProvider.notifier);

    return Semantics(
      label: '${item.name}, ${status.label}, ${item.sizeLabel}',
      child: Container(
        padding: const EdgeInsets.all(Gap.item),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: Radii.brCard,
          border: Border.all(
            color: status == UploadStatus.failed
                ? accent.withValues(alpha: 0.45)
                : p.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: Radii.brSm,
                  ),
                  child: Icon(status.icon, size: 18, color: accent),
                ),
                const SizedBox(width: Gap.icon),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge(
                          context,
                          color: p.textPrimary,
                          weight: FontWeights.bold,
                        ),
                      ),
                      const SizedBox(height: Space.s2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          context,
                          color: status == UploadStatus.failed
                              ? accent
                              : p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.inline),
                _Actions(item: item, queue: queue, accent: accent),
              ],
            ),
            if (status.showsProgress) ...[
              const SizedBox(height: Gap.item),
              ClipRRect(
                borderRadius: Radii.brPill,
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: Space.s6,
                  backgroundColor: p.surface2,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: Space.s6),
              Row(
                children: [
                  Text(
                    item.transferredLabel,
                    style: AppTypography.numeric(
                      context,
                      color: p.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (status.isActive)
                    Text(
                      '${item.speedLabel} · ${item.etaLabel} left',
                      style: AppTypography.numeric(context, color: p.textMuted),
                    ),
                ],
              ),
            ],
            if (item.isDuplicate && !status.isTerminal) ...[
              const SizedBox(height: Gap.inline),
              _Note(
                icon: Icons.copy_rounded,
                text: 'Possible duplicate of a file already queued',
                color: p.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (item.status == UploadStatus.failed && item.error != null) {
      return item.error!;
    }
    final parts = <String>[item.sizeLabel, item.source.label];
    if (item.attempt > 1) parts.add('attempt ${item.attempt}');
    if (item.priority == UploadPriority.high) parts.add('high priority');
    return parts.join(' · ');
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.item,
    required this.queue,
    required this.accent,
  });

  final UploadItem item;
  final UploadQueueController queue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = item.status;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.canPause)
          _IconAction(
            icon: Icons.pause_rounded,
            tooltip: 'Pause',
            onTap: () => queue.pause(item.id),
          ),
        if (s.canResume)
          _IconAction(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume',
            color: accent,
            onTap: () => queue.resume(item.id),
          ),
        if (s.canRetry)
          _IconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Retry',
            color: accent,
            onTap: () => queue.retry(item.id),
          ),
        if (!s.isTerminal)
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            onTap: () => queue.cancel(item.id),
          ),
        if (s.isTerminal)
          _IconAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Remove',
            onTap: () => queue.remove(item.id),
          ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: color ?? p.textMuted,
        // Keeps the 48x48 accessible target without inflating the row.
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: Space.s6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption(context, color: color),
          ),
        ),
      ],
    );
  }
}

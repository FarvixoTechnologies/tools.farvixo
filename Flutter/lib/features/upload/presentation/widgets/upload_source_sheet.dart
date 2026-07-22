import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../domain/upload_source.dart';
import '../../services/upload_picker_service.dart';

/// Source picker.
///
/// Only shows sources the current platform supports, so an iPhone never offers
/// "SMB share" and a desktop never offers "Camera". Sources that need
/// credentials render disabled with the reason inline rather than failing
/// silently on tap.
class UploadSourceSheet extends StatelessWidget {
  const UploadSourceSheet({super.key, required this.sources});

  final List<UploadSource> sources;

  /// Shows the sheet and resolves to the chosen source, or null on dismiss.
  static Future<UploadSource?> show(
    BuildContext context,
    List<UploadSource> sources,
  ) {
    return showModalBottomSheet<UploadSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadSourceSheet(sources: sources),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final groups = <SourceGroup, List<UploadSource>>{};
    for (final s in sources) {
      groups.putIfAbsent(s.group, () => []).add(s);
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(Gap.item),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: Radii.brSheet,
          border: Border.all(color: p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: Space.s4,
              margin: const EdgeInsets.symmetric(vertical: Gap.item),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: Radii.brPill,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  Gap.item,
                  Space.s0,
                  Gap.item,
                  Gap.dialog,
                ),
                children: [
                  for (final group in SourceGroup.values)
                    if (groups[group]?.isNotEmpty ?? false) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.s4,
                          Gap.item,
                          Space.s4,
                          Gap.inline,
                        ),
                        child: Text(
                          group.label.toUpperCase(),
                          style: AppTypography.overline(
                            context,
                            color: p.textMuted,
                          ),
                        ),
                      ),
                      for (final source in groups[group]!)
                        _SourceRow(source: source, group: group),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.group});

  final UploadSource source;
  final SourceGroup group;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final identity = group.identity;
    final accent = identity.accentOf(context);
    final blocked = UploadPickerService.unavailableReason(source);
    final enabled = blocked == null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: ListTile(
        onTap: enabled ? () => Navigator.pop(context, source) : null,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brTile),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.inline),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: identity.surfaceGradient(context),
            borderRadius: Radii.brSm,
            border: Border.all(color: identity.border(context)),
          ),
          child: Icon(source.icon, size: 20, color: accent),
        ),
        title: Text(
          source.label,
          style: AppTypography.labelLarge(
            context,
            color: p.textPrimary,
            weight: FontWeights.bold,
          ),
        ),
        subtitle: Text(
          blocked ?? source.detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(context, color: p.textMuted),
        ),
        trailing: enabled
            ? Icon(Icons.chevron_right_rounded, color: p.textMuted)
            : Icon(Icons.lock_outline_rounded, size: 16, color: p.textMuted),
      ),
    );
  }
}

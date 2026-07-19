import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

/// Section hub row on the main Settings screen.
class SettingsSectionTile extends StatelessWidget {
  const SettingsSectionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.emoji,
    required this.onTap,
    this.itemCount,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String? emoji;
  final VoidCallback onTap;
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            GlowIcon(icon: icon, color: iconColor, size: 44, iconSize: 20),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (emoji != null) ...[
                        Text(emoji!, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (itemCount != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: p.border),
                ),
                child: Text(
                  '$itemCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
              ),
            Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Row inside a section detail screen.
class SettingsItemTile extends StatelessWidget {
  const SettingsItemTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.destructive = false,
    this.isLast = false,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool destructive;
  final bool isLast;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final titleColor = !enabled
        ? p.textMuted
        : (destructive ? AppColors.error : p.textPrimary);
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Column(
        children: [
          InkWell(
            onTap: enabled ? onTap : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  GlowIcon(
                    icon: icon,
                    color: enabled ? iconColor : p.textMuted,
                    size: 42,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (trailingText != null) ...[
                    Flexible(
                      child: Text(
                        trailingText!,
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: destructive
                              ? AppColors.error
                              : AppColors.brandPrimaryHover,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: p.textMuted),
                    ],
                  ] else if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: p.textMuted),
                ],
              ),
            ),
          ),
          if (!isLast)
            Divider(height: 1, indent: 68, endIndent: 14, color: p.border),
        ],
      ),
    );
  }
}

/// Violet gradient pill switch used for boolean prefs.
class SettingsGlowSwitch extends StatelessWidget {
  const SettingsGlowSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 27,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: value ? AppColors.brandGradient : null,
          color: value ? null : AppPalette.of(context).surface2,
          border: Border.all(
            color: value ? Colors.transparent : AppPalette.of(context).border,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: .45),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: value ? Colors.white : AppPalette.of(context).textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "Soon" badge for unreleased settings.
class SettingsSoonBadge extends StatelessWidget {
  const SettingsSoonBadge({super.key, this.label = 'Soon'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.brandPrimaryHover.withValues(alpha: .35),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.brandPrimaryHover,
        ),
      ),
    );
  }
}

/// Disabled-state chip with a short reason (billing / sign-in / service).
class SettingsUnavailableBadge extends StatelessWidget {
  const SettingsUnavailableBadge({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final short = reason.length > 18 ? '${reason.substring(0, 16)}…' : reason;
    return Tooltip(
      message: reason,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppPalette.of(context).border),
        ),
        child: Text(
          short,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppPalette.of(context).textMuted,
          ),
        ),
      ),
    );
  }
}

/// Base-mode chip in the appearance sheet.
class AppearanceModeChip extends StatelessWidget {
  const AppearanceModeChip({
    super.key,
    required this.selected,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .14)
              : p.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent.withValues(alpha: .7) : p.border,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22, color: selected ? accent : p.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? accent : p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular accent swatch with check when selected.
class AccentSwatch extends StatelessWidget {
  const AccentSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? .55 : .3),
              blurRadius: selected ? 14 : 8,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? .9 : 0),
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

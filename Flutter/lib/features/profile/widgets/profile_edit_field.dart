import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/design_tokens.dart';

/// Enterprise Ultra input — icon → small label → large value (not inline).
class ProfileEditField extends StatefulWidget {
  const ProfileEditField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.prefix,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.validator,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.textInputAction,
    this.suffix,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? prefix;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool showCounter;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final bool enabled;

  @override
  State<ProfileEditField> createState() => _ProfileEditFieldState();
}

class _ProfileEditFieldState extends State<ProfileEditField> {
  late final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final inputBg = p.isDark ? AppColors.inputDark : p.surface2;
    final borderColor = p.isDark ? AppColors.inputDarkBorder : p.border;
    final focusColor = p.isDark ? AppColors.brandPrimaryHover : p.accent;

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.easeOut,
      constraints: BoxConstraints(minHeight: widget.maxLines > 1 ? 88 : 60),
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: Radii.brPanel,
        border: Border.all(
          color: _focused ? focusColor : borderColor,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              widget.icon,
              size: 22,
              color: _focused ? focusColor : p.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.labelSmall(context, color: _focused ? focusColor : p.textMuted, weight: FontWeights.semibold).copyWith(letterSpacing: 0.2),
                ),
                const SizedBox(height: 2),
                TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  readOnly: widget.readOnly,
                  enabled: widget.enabled,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  validator: widget.validator,
                  style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.semibold).copyWith(height: 1.25),
                  cursorColor: focusColor,
                  inputFormatters: widget.maxLength != null
                      ? [LengthLimitingTextInputFormatter(widget.maxLength)]
                      : null,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hint,
                    hintStyle: AppTypography.titleSmall(context, color: p.isDark
                          ? AppColors.inputDarkHint
                          : p.textMuted, weight: FontWeights.medium),
                    prefixText: widget.prefix,
                    prefixStyle: AppTypography.titleMedium(context, color: p.textSecondary, weight: FontWeights.bold),
                    counterText: '',
                    errorStyle: AppTypography.labelSmall(context, color: AppColors.error).copyWith(height: 1.2),
                  ),
                ),
                if (widget.showCounter && widget.maxLength != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller,
                      builder: (_, value, _) {
                        final n = value.text.length;
                        final max = widget.maxLength!;
                        final near = n >= max - 15;
                        return Text(
                          '$n / $max',
                          style: AppTypography.labelSmall(context, color: near
                                ? (n >= max
                                    ? AppColors.error
                                    : AppColors.warning)
                                : p.textMuted, weight: FontWeights.semibold),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (widget.suffix != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: widget.suffix!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Personal-tab row with chevron — opens a picker sheet.
class ProfilePickerRow extends StatelessWidget {
  const ProfilePickerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = 'Select',
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final inputBg = p.isDark ? AppColors.inputDark : p.surface2;
    final borderColor = p.isDark ? AppColors.inputDarkBorder : p.border;
    final hasValue = value.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: '$label, ${hasValue ? value : hint}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.brPanel,
          child: Ink(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: Radii.brPanel,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: p.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.labelSmall(context, color: p.textMuted, weight: FontWeights.semibold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasValue ? value : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium(context, color: hasValue ? p.textPrimary : AppColors.inputDarkHint, weight: FontWeights.semibold),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: p.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

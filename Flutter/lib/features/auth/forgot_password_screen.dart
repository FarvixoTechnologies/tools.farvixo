import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_typography.dart';

enum _ResetStep { email, code, newPassword, done }

/// Forgot Password flow — premium galaxy backdrop, glass step card.
/// Email → OTP → Verify → New Password → Login (logic unchanged).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  _ResetStep _step = _ResetStep.email;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is AuthException ? e.message : 'Something went wrong. Try again.',
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = ref.read(authProvider.notifier);
    final email = _emailController.text.trim();
    try {
      switch (_step) {
        case _ResetStep.email:
          await auth.sendPasswordReset(email);
          setState(() => _step = _ResetStep.code);
        case _ResetStep.code:
          await auth.verifyResetCode(email, _codeController.text.trim());
          setState(() => _step = _ResetStep.newPassword);
        case _ResetStep.newPassword:
          await auth.completePasswordReset(email, _passwordController.text);
          setState(() => _step = _ResetStep.done);
        case _ResetStep.done:
          break;
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _buttonLabel => switch (_step) {
        _ResetStep.email => 'Send Reset Code',
        _ResetStep.code => 'Verify Code',
        _ResetStep.newPassword => 'Save New Password',
        _ResetStep.done => 'Back to Sign In',
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, 12, Insets.md, Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: PremiumHeader(
                        title: 'Reset password',
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.go('/login'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 1,
                      child: _step == _ResetStep.done
                          ? _SuccessView(
                              onDone: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/login'),
                            )
                          : GlassCard(
                              padding: const EdgeInsets.all(Insets.gutter),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // step icon
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: GlowIcon(
                                        icon: switch (_step) {
                                          _ResetStep.email =>
                                            Icons.lock_reset_rounded,
                                          _ResetStep.code =>
                                            Icons.pin_rounded,
                                          _ => Icons.password_rounded,
                                        },
                                        color: p.accent,
                                        size: 52,
                                        iconSize: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      switch (_step) {
                                        _ResetStep.email =>
                                          'Forgot your password?',
                                        _ResetStep.code => 'Enter the code',
                                        _ => 'Create a new password',
                                      },
                                      style: AppTypography.headlineSmall(context, color: p.textPrimary, weight: FontWeights.extrabold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      switch (_step) {
                                        _ResetStep.email =>
                                          "Enter your email and we'll send you a 6-digit reset code.",
                                        _ResetStep.code =>
                                          'We sent a 6-digit code to ${_emailController.text.trim()}.',
                                        _ =>
                                          'Choose a strong password you haven\'t used before.',
                                      },
                                      style: AppTypography.bodyLarge(context,
                                          color: p.textSecondary).copyWith(height: 1.4),
                                    ),
                                    const SizedBox(height: 24),
                                    if (_step == _ResetStep.email)
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autofillHints: const [
                                          AutofillHints.email
                                        ],
                                        decoration: const InputDecoration(
                                          hintText: 'Email address',
                                          prefixIcon:
                                              Icon(Icons.mail_outline_rounded),
                                        ),
                                        validator: Validators.email,
                                      ),
                                    if (_step == _ResetStep.code) ...[
                                      TextFormField(
                                        controller: _codeController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode
                                        ],
                                        decoration: const InputDecoration(
                                          hintText: '6-digit code',
                                          counterText: '',
                                          prefixIcon: Icon(Icons.pin_rounded),
                                        ),
                                        validator: Validators.otp,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _loading
                                              ? null
                                              : () => ref
                                                  .read(authProvider.notifier)
                                                  .sendPasswordReset(
                                                      _emailController.text
                                                          .trim()),
                                          child: const Text('Resend code'),
                                        ),
                                      ),
                                    ],
                                    if (_step == _ResetStep.newPassword)
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscure,
                                        autofillHints: const [
                                          AutofillHints.newPassword
                                        ],
                                        decoration: InputDecoration(
                                          hintText: 'New password',
                                          helperText:
                                              'Min. 8 chars with upper, lower, number & symbol',
                                          prefixIcon: const Icon(
                                              Icons.lock_outline_rounded),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscure
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded),
                                            onPressed: () => setState(
                                                () => _obscure = !_obscure),
                                          ),
                                        ),
                                        validator: Validators.password,
                                      ),
                                    const SizedBox(height: 24),
                                    PrimaryButton(
                                      label: _buttonLabel,
                                      isLoading: _loading,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GlassCard(
      glowColor: AppColors.success,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: .15),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: .5)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.success.withValues(alpha: .3),
                      blurRadius: 28),
                ],
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 52, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 24),
          Text('Password updated',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(context, color: p.textPrimary, weight: FontWeights.extrabold)),
          const SizedBox(height: 8),
          Text(
            'Your password has been changed. Sign in with your new password.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge(context, color: p.textSecondary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: 'Back to Sign In', onPressed: onDone),
        ],
      ),
    );
  }
}

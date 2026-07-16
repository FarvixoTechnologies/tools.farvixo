import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../utils/validators.dart';
import '../../widgets/farvixo_logo.dart';
import '../../widgets/premium_kit.dart';
import '../../widgets/primary_button.dart';

/// Registration — premium galaxy backdrop, glass form card, password strength
/// meter. Full password policy preserved (see docs/AUTHENTICATION_SYSTEM.md).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  double _strength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signUp(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AuthException
                ? e.message
                : 'Something went wrong. Try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _strengthColor {
    if (_strength < 0.4) return AppColors.error;
    if (_strength < 0.7) return AppColors.goldPremium;
    return AppColors.success;
  }

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: PremiumHeader(
                        title: 'Create account',
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.go('/login'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        children: [
                          const FarvixoLogo(size: 64),
                          const SizedBox(height: 14),
                          ShaderMask(
                            shaderCallback: (b) => LinearGradient(colors: [
                              p.textPrimary,
                              p.accent,
                            ]).createShader(b),
                            child: const Text('Join Farvixo',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 6),
                          Text('One account. Every tool. Everywhere.',
                              style: TextStyle(color: p.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      index: 2,
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  hintText: 'Full name',
                                  prefixIcon:
                                      Icon(Icons.person_outline_rounded),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter your name'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  hintText: 'Email address',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                onChanged: (v) => setState(() => _strength =
                                    Validators.passwordStrength(v)),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  helperText:
                                      'Min. 8 chars with upper, lower, number & symbol',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: Validators.password,
                              ),
                              if (_strength > 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: _strength,
                                          minHeight: 6,
                                          color: _strengthColor,
                                          backgroundColor: p.border,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      Validators.strengthLabel(_strength),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _strengthColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmController,
                                obscureText: _obscure,
                                decoration: const InputDecoration(
                                  hintText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (v) => v != _passwordController.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              const SizedBox(height: 26),
                              PrimaryButton(
                                label: 'Create Account',
                                isLoading: _loading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By signing up you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
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

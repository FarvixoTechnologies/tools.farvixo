import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/farvixo_logo.dart';
import '../../widgets/social_login_button.dart';

enum _LoginMethod { email, phone }

/// ---------------------------------------------------------------------------
/// METHOD VISIBILITY — sab methods code me ready hain.
/// Kisi method ko enable karne ke liye bas `true` kar do.
/// ---------------------------------------------------------------------------
const Map<String, bool> kAuthMethodVisibility = {
  'email': true,
  'google': true,
  'github': true,
  // ---- ready but hidden ----
  'apple': false,
  'microsoft': false,
  'phone': false,
  'passkey': false,
  'qr': false,
  'wallet': false,
};

/// Login Screen v3 — FARVIXO Next-Gen Authentication.
/// Animated particles, glowing shield logo, gradient shimmer title,
/// staggered entrance, animated method cards, shake-on-error.
/// (see docs/AUTHENTICATION_SYSTEM.md — Login Screen)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _LoginMethod _method = _LoginMethod.email;
  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;
  bool _otpSent = false;
  bool _biometricAvailable = false;
  String? _socialLoading;

  // ------------------------------------------------------------ animations
  late final AnimationController _bgController;     // particles / orbs loop
  late final AnimationController _introController;  // staggered entrance
  late final AnimationController _pulseController;  // glow pulse
  late final AnimationController _shakeController;  // error shake

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 24))
          ..repeat();
    _introController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canUse = await ref.read(authProvider.notifier).canUseBiometricLogin;
    if (!canUse) return;
    final hardware = await ref.read(biometricServiceProvider).isAvailable;
    if (mounted && hardware) setState(() => _biometricAvailable = true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  void _showError(Object e) {
    if (!mounted) return;
    _shakeController.forward(from: 0);
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

  Future<void> _afterLogin() async {
    final auth = ref.read(authProvider.notifier);
    final hardware = await ref.read(biometricServiceProvider).isAvailable;
    final alreadyEnabled = await auth.canUseBiometricLogin;
    if (mounted && hardware && !alreadyEnabled) {
      final enable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable biometric sign-in?'),
          content: const Text(
              'Use your fingerprint or face to sign in faster next time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (enable == true) await auth.enableBiometricLogin();
    }
    if (mounted) context.go('/home');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }
    setState(() => _loading = true);
    final auth = ref.read(authProvider.notifier);
    try {
      if (_method == _LoginMethod.email) {
        await auth.signIn(
          _emailController.text.trim(),
          _passwordController.text,
          rememberMe: _rememberMe,
        );
        await _afterLogin();
      } else if (!_otpSent) {
        await auth.sendOtp(_phoneController.text.trim());
        if (mounted) setState(() => _otpSent = true);
      } else {
        await auth.verifyOtp(
          _phoneController.text.trim(),
          _otpController.text.trim(),
        );
        await _afterLogin();
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _social(String provider) async {
    setState(() => _socialLoading = provider);
    try {
      await ref.read(authProvider.notifier).signInWithProvider(provider);
      await _afterLogin();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  Future<void> _biometric() async {
    try {
      final ok = await ref.read(biometricServiceProvider).authenticate();
      if (!ok) return;
      await ref.read(authProvider.notifier).signInWithBiometrics();
      if (mounted) context.go('/home');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _guest() async {
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
      if (mounted) context.go('/home');
    } catch (e) {
      _showError(e);
    }
  }

  void _onMethodCardTap(String id) {
    switch (id) {
      case 'email':
        setState(() {
          _method = _LoginMethod.email;
          _otpSent = false;
        });
      case 'phone':
        setState(() {
          _method = _LoginMethod.phone;
          _otpSent = false;
        });
      case 'google':
      case 'github':
      case 'apple':
      case 'microsoft':
        _social(id);
      case 'passkey':
      case 'qr':
      case 'wallet':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$id login coming soon'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // --------------------------------------------------------------- helpers

  /// Staggered fade + slide entrance.
  Widget _entrance({required int index, required Widget child}) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .18),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final buttonLabel = _method == _LoginMethod.email
        ? 'Sign In'
        : (_otpSent ? 'Verify & Sign In' : 'Send Code');

    return Scaffold(
      backgroundColor: const Color(0xFF05010F),
      body: Stack(
        children: [
          // ================= animated background =================
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) => CustomPaint(
                  painter: _AuthBackgroundPainter(_bgController.value),
                ),
              ),
            ),
          ),

          // ================= content =================
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                        // ---------------- glowing logo ----------------
                        _entrance(
                          index: 0,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final t = _pulseController.value;
                                return Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.brandPrimary
                                            .withValues(alpha: .25 + t * .3),
                                        blurRadius: 34 + t * 26,
                                        spreadRadius: 2 + t * 5,
                                      ),
                                      BoxShadow(
                                        color: AppColors.brandMagenta
                                            .withValues(alpha: .12 + t * .18),
                                        blurRadius: 60 + t * 30,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                );
                              },
                              child: const FarvixoLogo(size: 64),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ---------------- shimmer title ----------------
                        _entrance(
                          index: 1,
                          child: _ShimmerTitle(
                            controller: _bgController,
                            text: 'Welcome Back! 👋',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _entrance(
                          index: 2,
                          child: const Text(
                            'Sign in to continue to Farvixo',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _entrance(
                          index: 3,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: Radii.brPill,
                                  border: Border.all(
                                    color: AppColors.brandPrimaryHover
                                        .withValues(
                                            alpha: .35 +
                                                _pulseController.value * .35),
                                  ),
                                  color: AppColors.brandPrimary
                                      .withValues(alpha: .10),
                                ),
                                child: const Text(
                                  '🔒 Next-Gen Security',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFC4B5FD),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // ---------------- method cards ----------------
                        _entrance(
                          index: 4,
                          child: _MethodCardsRow(
                            selectedEmail: _method == _LoginMethod.email,
                            selectedPhone: _method == _LoginMethod.phone,
                            socialLoading: _socialLoading,
                            isIOS: isIOS,
                            onTap: _onMethodCardTap,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ---------------- form (shake wrapper) ----------------
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final t = _shakeController.value;
                            final dx =
                                math.sin(t * math.pi * 6) * (1 - t) * 10;
                            return Transform.translate(
                                offset: Offset(dx, 0), child: child);
                          },
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ------------------- email fields
                                if (_method == _LoginMethod.email)
                                  _entrance(
                                    index: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _GlowField(
                                          child: TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            autofillHints: const [
                                              AutofillHints.email
                                            ],
                                            decoration: const InputDecoration(
                                              hintText: 'Email or Username',
                                              prefixIcon: Icon(
                                                  Icons.mail_outline_rounded),
                                            ),
                                            validator: Validators.email,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _GlowField(
                                          child: TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscure,
                                            autofillHints: const [
                                              AutofillHints.password
                                            ],
                                            decoration: InputDecoration(
                                              hintText: 'Password',
                                              prefixIcon: const Icon(
                                                  Icons.lock_outline_rounded),
                                              suffixIcon: IconButton(
                                                tooltip: _obscure
                                                    ? 'Show password'
                                                    : 'Hide password',
                                                icon: Icon(_obscure
                                                    ? Icons
                                                        .visibility_off_rounded
                                                    : Icons
                                                        .visibility_rounded),
                                                onPressed: () => setState(
                                                    () =>
                                                        _obscure = !_obscure),
                                              ),
                                            ),
                                            validator:
                                                Validators.loginPassword,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              onChanged: (v) => setState(() =>
                                                  _rememberMe = v ?? true),
                                            ),
                                            const Text('Remember me',
                                                style:
                                                    TextStyle(fontSize: 13)),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () => context
                                                  .push('/forgot-password'),
                                              child: const Text(
                                                  'Forgot Password?'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                // ------------------- phone fields (ready, hidden method)
                                if (_method == _LoginMethod.phone) ...[
                                  _GlowField(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      autofillHints: const [
                                        AutofillHints.telephoneNumber
                                      ],
                                      enabled: !_otpSent,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Phone number (with country code)',
                                        prefixIcon:
                                            Icon(Icons.phone_iphone_rounded),
                                      ),
                                      validator: Validators.phone,
                                    ),
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 16),
                                    _GlowField(
                                      child: TextFormField(
                                        controller: _otpController,
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
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _loading
                                            ? null
                                            : () => ref
                                                .read(authProvider.notifier)
                                                .sendOtp(_phoneController.text
                                                    .trim()),
                                        child: const Text('Resend code'),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ---------------- gradient sign-in button ----------------
                        _entrance(
                          index: 6,
                          child: _GlowGradientButton(
                            label: buttonLabel,
                            isLoading: _loading,
                            pulse: _pulseController,
                            onPressed: _submit,
                          ),
                        ),

                        // ---------------- biometric ----------------
                        if (_biometricAvailable) ...[
                          const SizedBox(height: 14),
                          _entrance(
                            index: 7,
                            child: _BiometricButton(
                              pulse: _pulseController,
                              onPressed: _biometric,
                            ),
                          ),
                        ],

                        // ---------------- social buttons ----------------
                        const SizedBox(height: 24),
                        _entrance(
                          index: 8,
                          child: const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (kAuthMethodVisibility['google'] == true)
                          _entrance(
                            index: 9,
                            child: SocialLoginButton(
                              label: 'Continue with Google',
                              leading: const GoogleGlyph(),
                              isLoading: _socialLoading == 'google',
                              onPressed: () => _social('google'),
                            ),
                          ),
                        if (kAuthMethodVisibility['github'] == true) ...[
                          const SizedBox(height: 12),
                          _entrance(
                            index: 10,
                            child: SocialLoginButton(
                              label: 'Continue with GitHub',
                              leading: const Icon(Icons.code_rounded, size: 20),
                              isLoading: _socialLoading == 'github',
                              onPressed: () => _social('github'),
                            ),
                          ),
                        ],
                        // ---- ready but hidden (flip flags in kAuthMethodVisibility) ----
                        if (kAuthMethodVisibility['apple'] == true && isIOS) ...[
                          const SizedBox(height: 12),
                          SocialLoginButton(
                            label: 'Continue with Apple',
                            leading: const Icon(Icons.apple, size: 22),
                            isLoading: _socialLoading == 'apple',
                            onPressed: () => _social('apple'),
                          ),
                        ],
                        if (kAuthMethodVisibility['microsoft'] == true) ...[
                          const SizedBox(height: 12),
                          SocialLoginButton(
                            label: 'Continue with Microsoft',
                            leading: const Icon(Icons.window_rounded, size: 20),
                            isLoading: _socialLoading == 'microsoft',
                            onPressed: () => _social('microsoft'),
                          ),
                        ],

                        // ---------------- footer ----------------
                        const SizedBox(height: 20),
                        _entrance(
                          index: 11,
                          child: OutlinedButton.icon(
                            onPressed: _guest,
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Continue as Guest'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _entrance(
                          index: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account?",
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                              TextButton(
                                onPressed: () => context.push('/register'),
                                child: const Text('Sign Up'),
                              ),
                            ],
                          ),
                        ),
                        _entrance(
                          index: 13,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {},
                                child: const Text('Privacy Policy',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              const Text('•',
                                  style:
                                      TextStyle(color: AppColors.textMuted)),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Terms & Conditions',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shimmer gradient title
// =============================================================================
class _ShimmerTitle extends StatelessWidget {
  const _ShimmerTitle({required this.controller, required this.text});

  final AnimationController controller;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final shift = controller.value * 6 * math.pi;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
              Color(0xFF22D3EE),
              Color(0xFF8B5CF6),
            ],
            transform: GradientRotation(shift * .05),
            tileMode: TileMode.mirror,
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: .5,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Method cards row — Email / Google / GitHub visible; others coded & hidden
// =============================================================================
class _MethodCardsRow extends StatelessWidget {
  const _MethodCardsRow({
    required this.selectedEmail,
    required this.selectedPhone,
    required this.socialLoading,
    required this.isIOS,
    required this.onTap,
  });

  final bool selectedEmail;
  final bool selectedPhone;
  final String? socialLoading;
  final bool isIOS;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    final cards = <_MethodCardData>[
      _MethodCardData('email', 'Email', Icons.mail_outline_rounded,
          selected: selectedEmail),
      _MethodCardData('google', 'Google', Icons.g_mobiledata_rounded,
          loading: socialLoading == 'google'),
      _MethodCardData('github', 'GitHub', Icons.code_rounded,
          loading: socialLoading == 'github'),
      // ---- ready, hidden via kAuthMethodVisibility ----
      _MethodCardData('apple', 'Apple', Icons.apple,
          loading: socialLoading == 'apple'),
      _MethodCardData('microsoft', 'Microsoft', Icons.window_rounded,
          loading: socialLoading == 'microsoft'),
      _MethodCardData('phone', 'Phone', Icons.phone_iphone_rounded,
          selected: selectedPhone),
      _MethodCardData('passkey', 'Passkey', Icons.key_rounded),
      _MethodCardData('qr', 'QR Code', Icons.qr_code_rounded),
      _MethodCardData(
          'wallet', 'Wallet', Icons.account_balance_wallet_outlined),
    ]
        .where((c) => kAuthMethodVisibility[c.id] == true)
        .where((c) => c.id != 'apple' || isIOS)
        .toList();

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _MethodCard(data: cards[i], onTap: onTap)),
        ],
      ],
    );
  }
}

class _MethodCardData {
  const _MethodCardData(this.id, this.label, this.icon,
      {this.selected = false, this.loading = false});
  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final bool loading;
}

class _MethodCard extends StatefulWidget {
  const _MethodCard({required this.data, required this.onTap});
  final _MethodCardData data;
  final void Function(String id) onTap;

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap(d.id);
      },
      child: AnimatedScale(
        scale: _pressed ? .93 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: Radii.brCard,
            gradient: d.selected
                ? LinearGradient(colors: [
                    AppColors.brandPrimary.withValues(alpha: .28),
                    AppColors.brandMagenta.withValues(alpha: .18),
                  ])
                : null,
            color: d.selected ? null : AppColors.bgSurface.withValues(alpha: .75),
            border: Border.all(
              color: d.selected
                  ? AppColors.brandPrimaryHover
                  : AppColors.borderSubtle,
              width: d.selected ? 1.4 : 1,
            ),
            boxShadow: d.selected
                ? [
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: .35),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              if (d.loading)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Icon(d.icon,
                    size: 26,
                    color: d.selected
                        ? Colors.white
                        : AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                d.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: d.selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      d.selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Glow field wrapper — subtle violet glow behind focused inputs
// =============================================================================
class _GlowField extends StatefulWidget {
  const _GlowField({required this.child});
  final Widget child;

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: Radii.brButton,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: .30),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// Glowing gradient CTA with loading state
// =============================================================================
class _GlowGradientButton extends StatelessWidget {
  const _GlowGradientButton({
    required this.label,
    required this.isLoading,
    required this.pulse,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final AnimationController pulse;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.brCard,
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.brandPrimary.withValues(alpha: .30 + t * .25),
                blurRadius: 22 + t * 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: Radii.brCard,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ),
              borderRadius: Radii.brCard,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Biometric button — pulsing fingerprint ring
// =============================================================================
class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.pulse, required this.onPressed});
  final AnimationController pulse;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(
            color: AppColors.brandPrimaryHover
                .withValues(alpha: .35 + pulse.value * .45),
          ),
        ),
        icon: Icon(
          Icons.fingerprint_rounded,
          color: Color.lerp(AppColors.brandPrimaryHover,
              const Color(0xFFEC4899), pulse.value),
        ),
        label: const Text('Sign in with biometrics'),
      ),
    );
  }
}

// =============================================================================
// Animated background — floating particles + soft gradient orbs
// =============================================================================
class _AuthBackgroundPainter extends CustomPainter {
  _AuthBackgroundPainter(this.t);
  final double t;

  static final List<_Particle> _particles = List.generate(70, (i) {
    final rnd = math.Random(i * 7 + 3);
    return _Particle(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      r: rnd.nextDouble() * 1.6 + .4,
      speed: rnd.nextDouble() * .5 + .15,
      phase: rnd.nextDouble() * math.pi * 2,
      pink: rnd.nextDouble() > .75,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    // orbs
    final orbPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    final drift = math.sin(t * 2 * math.pi) * 40;

    orbPaint.color = const Color(0xFF6D28D9).withValues(alpha: .30);
    canvas.drawCircle(
        Offset(size.width * .12 + drift, size.height * .10), 150, orbPaint);

    orbPaint.color = const Color(0xFFBE185D).withValues(alpha: .22);
    canvas.drawCircle(
        Offset(size.width * .92 - drift, size.height * .88), 160, orbPaint);

    orbPaint.color = const Color(0xFF1D4ED8).withValues(alpha: .16);
    canvas.drawCircle(
        Offset(size.width * .80 + drift * .5, size.height * .35), 120, orbPaint);

    // particles
    final p = Paint();
    for (final pt in _particles) {
      final y = (pt.y - t * pt.speed) % 1.0;
      final twinkle =
          .25 + (math.sin(t * 40 * pt.speed + pt.phase) + 1) / 2 * .55;
      p.color = (pt.pink ? const Color(0xFFEC4899) : const Color(0xFFA78BFA))
          .withValues(alpha: twinkle);
      canvas.drawCircle(
          Offset(pt.x * size.width, y * size.height), pt.r, p);
    }
  }

  @override
  bool shouldRepaint(_AuthBackgroundPainter oldDelegate) => oldDelegate.t != t;
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.phase,
    required this.pink,
  });
  final double x;
  final double y;
  final double r;
  final double speed;
  final double phase;
  final bool pink;
}

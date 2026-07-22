import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/profile_details.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/profile_details_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../theme/category_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/validators.dart';
import '../../widgets/premium_kit.dart';
import 'widgets/profile_edit_field.dart';

/// Edit Profile — Enterprise Ultra UI v2.0
/// Glass app bar · M3 segmented tabs · live preview · dirty-gated Save.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _UsernameStatus { idle, checking, available, taken, invalid }

enum _SavePhase { idle, saving, success, error }

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with TickerProviderStateMixin {
  static const _reservedUsernames = {
    'admin',
    'farvixo',
    'support',
    'root',
    'null',
    'system',
    'help',
  };

  late ProfileDetails _draft;
  late ProfileDetails _baseline;
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _tab = 0;
  bool _dirty = false;
  _SavePhase _savePhase = _SavePhase.idle;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _usernameDebounce;

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: Motion.page,
  );
  late final AnimationController _successCtrl = AnimationController(
    vsync: this,
    duration: Motion.page,
  );

  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _bio = TextEditingController();
  final _website = TextEditingController();
  final _occupation = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();

  String _country = '';
  String _language = '';
  String _birthday = '';
  String _gender = '';
  String _timezone = '';

  @override
  void initState() {
    super.initState();
    final current = ref.read(profileDetailsProvider);
    final user = ref.read(authProvider);
    _baseline = current;
    _draft = current;
    _username.text = current.username;
    _fullName.text = user?.fullName ??
        (current.displayName.isNotEmpty
            ? current.displayName
            : (user?.displayName ?? ''));
    _bio.text = current.bio;
    _website.text = current.website;
    _occupation.text = current.occupation;
    _company.text = current.company;
    _location.text = current.location;
    _country = current.country;
    _language = current.language.isNotEmpty
        ? current.language
        : 'English';
    _birthday = current.birthday;
    _gender = current.gender;
    _timezone = current.timezone.isNotEmpty
        ? current.timezone
        : DateTime.now().timeZoneName;

    for (final c in _textControllers) {
      c.addListener(_markDirty);
    }
  }

  List<TextEditingController> get _textControllers => [
        _username,
        _fullName,
        _bio,
        _website,
        _occupation,
        _company,
        _location,
      ];

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _setPersonal(VoidCallback apply) {
    setState(() {
      apply();
      _dirty = true;
    });
  }

  ProfileDetails _collect() {
    final name = _fullName.text.trim();
    return _draft.copyWith(
      username: _username.text.trim().replaceFirst(RegExp(r'^@'), ''),
      displayName: name,
      bio: _bio.text.trim(),
      country: _country.trim(),
      language: _language.trim(),
      birthday: _birthday.trim(),
      gender: _gender.trim(),
      website: _website.text.trim(),
      occupation: _occupation.text.trim(),
      company: _company.text.trim(),
      location: _location.text.trim(),
      timezone: _timezone.trim(),
    );
  }

  Future<void> _pickImage({required bool cover}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: cover ? 1920 : 1024,
      maxHeight: cover ? 1080 : 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dirty = true;
      _draft = cover
          ? _draft.copyWith(coverUrl: file.path)
          : _draft.copyWith(avatarUrl: file.path);
    });
  }

  void _scheduleUsernameCheck(String raw) {
    _usernameDebounce?.cancel();
    final cleaned = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleaned.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (Validators.username(cleaned) != null) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }
    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(Motion.page, () {
      if (!mounted) return;
      final taken = _reservedUsernames.contains(cleaned.toLowerCase()) &&
          cleaned.toLowerCase() != _baseline.username.toLowerCase();
      setState(() {
        _usernameStatus =
            taken ? _UsernameStatus.taken : _UsernameStatus.available;
      });
    });
  }

  Future<void> _save({bool pop = true}) async {
    if (!_dirty || _savePhase == _SavePhase.saving) return;
    if (!(_formKey.currentState?.validate() ?? false) ||
        _usernameStatus == _UsernameStatus.taken ||
        _usernameStatus == _UsernameStatus.invalid) {
      await _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      _showErrorSnack('Please fix the highlighted fields');
      _pageController.animateToPage(
        0,
        duration: Motion.slow,
        curve: Motion.easeOut,
      );
      setState(() => _tab = 0);
      return;
    }

    setState(() => _savePhase = _SavePhase.saving);
    try {
      final next = _collect();
      await ref.read(profileDetailsProvider.notifier).save(next);

      final user = ref.read(authProvider);
      final name = _fullName.text.trim();
      if (user != null && !user.isGuest && name.isNotEmpty) {
        await ref.read(authProvider.notifier).applyLocalUser(
              user.copyWith(
                fullName: name,
                avatarUrl: next.avatarUrl ?? user.avatarUrl,
              ),
            );
      }

      if (!mounted) return;
      setState(() {
        _savePhase = _SavePhase.success;
        _baseline = next;
        _draft = next;
        _dirty = false;
      });
      _successCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(Motion.refreshDwell);
      if (!mounted) return;
      setState(() => _savePhase = _SavePhase.idle);
      if (pop && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _savePhase = _SavePhase.error);
      await _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      _showErrorSnack('Couldn’t save profile. Try again.');
      if (mounted) setState(() => _savePhase = _SavePhase.idle);
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.brButton),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final p = AppPalette.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.isDark ? AppColors.zincSurface : p.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brPanel),
        title: Text(
          'Unsaved changes',
          style: AppTypography.bodyLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
        ),
        content: Text(
          'Save before leaving?',
          style: AppTypography.bodyLarge(context, color: p.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Discard', style: AppTypography.bodyLarge(context, color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('Stay', style: AppTypography.bodyLarge(context, color: p.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _save(pop: false);
      return !_dirty;
    }
    return action == 'discard';
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _pageController.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    for (final c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bg = p.isDark ? AppColors.zincBase : p.bg;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: PremiumBackground(
          child: SafeArea(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (context, child) {
                    final t = _shakeCtrl.value;
                    final dx = math.sin(t * math.pi * 6) * (1 - t) * 8;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: _GlassAppBar(
                    dirty: _dirty,
                    phase: _savePhase,
                    successProgress: _successCtrl,
                    onCancel: () async {
                      final ok = await _onWillPop();
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
                    onSave: () => _save(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _SegmentedTabs(
                    index: _tab,
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _tab = i);
                      _pageController.animateToPage(
                        i,
                        duration: Motion.slow,
                        curve: Motion.easeOut,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _tab = i),
                      children: [
                        _scroll(_generalTab(p)),
                        _scroll(_personalTab(p)),
                        _scroll(_previewTab(p)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scroll(Widget child) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [child],
      );

  Widget _generalTab(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoverPhoto(
          url: _draft.coverUrl,
          onPick: () => _pickImage(cover: true),
          onRemove: () => setState(() {
            _dirty = true;
            _draft = _draft.copyWith(clearCover: true);
          }),
        ),
        const SizedBox(height: 20),
        _AvatarBlock(
          url: _draft.avatarUrl,
          onPick: () => _pickImage(cover: false),
          onRemove: () => setState(() {
            _dirty = true;
            _draft = _draft.copyWith(clearAvatar: true);
          }),
        ),
        const SizedBox(height: 20),
        ProfileEditField(
          controller: _fullName,
          label: 'Full Name',
          icon: Icons.badge_outlined,
          hint: 'Your name',
          maxLength: 50,
          validator: Validators.fullName,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _username,
          label: 'Username',
          icon: Icons.alternate_email_rounded,
          prefix: '@',
          hint: 'username',
          maxLength: 20,
          validator: Validators.username,
          textInputAction: TextInputAction.next,
          onChanged: _scheduleUsernameCheck,
          suffix: _UsernameBadge(status: _usernameStatus),
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _bio,
          label: 'Bio',
          icon: Icons.notes_rounded,
          hint: 'Tell the world who you are…',
          maxLines: 5,
          minLines: 3,
          maxLength: 160,
          showCounter: true,
          validator: Validators.bio,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }

  Widget _personalTab(AppPalette p) {
    return Column(
      children: [
        ProfilePickerRow(
          icon: Icons.public_rounded,
          label: 'Country',
          value: _country,
          onTap: () => _openSearchPicker(
            title: 'Country',
            items: _kCountries
                .map((c) => _PickerItem(label: '${c.$1}  ${c.$2}', value: c.$2))
                .toList(),
            current: _country,
            onPick: (v) => _setPersonal(() => _country = v),
          ),
        ),
        const SizedBox(height: 16),
        ProfilePickerRow(
          icon: Icons.translate_rounded,
          label: 'Language',
          value: _language,
          onTap: () => _openSearchPicker(
            title: 'Language',
            items: [
              ...supportedLanguages.map(
                (l) => _PickerItem(
                  label: '${l.name} · ${l.nativeName}',
                  value: l.name,
                ),
              ),
              ..._kExtraLanguages,
            ],
            current: _language,
            onPick: (v) => _setPersonal(() => _language = v),
          ),
        ),
        const SizedBox(height: 16),
        ProfilePickerRow(
          icon: Icons.cake_outlined,
          label: 'Birthday',
          value: _birthday,
          hint: 'Select date',
          onTap: _pickBirthday,
        ),
        const SizedBox(height: 16),
        ProfilePickerRow(
          icon: Icons.wc_rounded,
          label: 'Gender (Optional)',
          value: _gender,
          hint: 'Optional',
          onTap: () => _openSearchPicker(
            title: 'Gender',
            items: const [
              _PickerItem(label: 'Prefer not to say', value: ''),
              _PickerItem(label: 'Male', value: 'Male'),
              _PickerItem(label: 'Female', value: 'Female'),
              _PickerItem(label: 'Non-binary', value: 'Non-binary'),
              _PickerItem(label: 'Other', value: 'Other'),
            ],
            current: _gender,
            onPick: (v) => _setPersonal(() => _gender = v),
          ),
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _website,
          label: 'Website',
          icon: Icons.link_rounded,
          hint: 'https://',
          keyboardType: TextInputType.url,
          validator: Validators.website,
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _occupation,
          label: 'Occupation (Optional)',
          icon: Icons.work_outline_rounded,
          hint: 'What you do',
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _company,
          label: 'Company (Optional)',
          icon: Icons.business_rounded,
          hint: 'Where you work',
        ),
        const SizedBox(height: 16),
        ProfileEditField(
          controller: _location,
          label: 'Location (Optional)',
          icon: Icons.location_on_outlined,
          hint: 'City, region',
        ),
        const SizedBox(height: 16),
        ProfilePickerRow(
          icon: Icons.schedule_rounded,
          label: 'Timezone',
          value: _timezone,
          onTap: () => _openSearchPicker(
            title: 'Timezone',
            items: _kTimezones
                .map((z) => _PickerItem(label: z, value: z))
                .toList(),
            current: _timezone,
            onPick: (v) => _setPersonal(() => _timezone = v),
          ),
        ),
      ],
    );
  }

  Widget _previewTab(AppPalette p) {
    final draft = _collect();
    final user = ref.watch(authProvider);
    final isPro = user?.isPro ?? false;
    final isVerified = user != null && !user.isGuest;

    return _LivePreviewCard(
      coverUrl: draft.coverUrl,
      avatarUrl: draft.avatarUrl,
      displayName: draft.displayName.isEmpty ? 'Your Name' : draft.displayName,
      username: draft.username.isEmpty ? 'username' : draft.username,
      bio: draft.hasBio ? draft.bio : 'No bio yet',
      hasBio: draft.hasBio,
      country: draft.country,
      isPro: isPro,
      isVerified: isVerified,
      joinedLabel: 'Joined Farvixo',
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    DateTime initial = DateTime(now.year - 20);
    if (_birthday.isNotEmpty) {
      final parsed = DateTime.tryParse(_birthday);
      if (parsed != null && !parsed.isAfter(now)) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select birthday',
    );
    if (picked == null) return;
    if (picked.isAfter(now)) {
      _showErrorSnack('Birthday cannot be in the future');
      return;
    }
    _setPersonal(() {
      _birthday =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _openSearchPicker({
    required String title,
    required List<_PickerItem> items,
    required String current,
    required ValueChanged<String> onPick,
  }) async {
    final p = AppPalette.of(context);
    final query = TextEditingController();
    var filtered = List<_PickerItem>.from(items);

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            void applyFilter(String q) {
              final needle = q.trim().toLowerCase();
              setModal(() {
                filtered = needle.isEmpty
                    ? List<_PickerItem>.from(items)
                    : items
                        .where(
                          (e) =>
                              e.label.toLowerCase().contains(needle) ||
                              e.value.toLowerCase().contains(needle),
                        )
                        .toList();
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) {
                return ClipRRect(
                  borderRadius:
                      Radii.brSheetTop,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Material(
                      color: (p.isDark
                              ? AppColors.zincSurface
                              : p.surface)
                          .withValues(alpha: 0.94),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: p.border,
                              borderRadius: Radii.brPill,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Text(
                                  title,
                                  style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: Icon(Icons.close_rounded,
                                      color: p.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              controller: query,
                              onChanged: applyFilter,
                              autofocus: true,
                              style: AppTypography.bodyLarge(context, color: p.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search…',
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: p.textMuted),
                                filled: true,
                                fillColor: p.isDark
                                    ? AppColors.inputDark
                                    : p.surface2,
                                border: OutlineInputBorder(
                                  borderRadius: Radii.brCard,
                                  borderSide: BorderSide(color: p.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: Radii.brCard,
                                  borderSide: BorderSide(color: p.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: Radii.brCard,
                                  borderSide: BorderSide(
                                    color: p.isDark
                                        ? AppColors.brandPrimaryHover
                                        : p.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollCtrl,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                final selected = item.value == current ||
                                    (item.value.isEmpty && current.isEmpty);
                                return ListTile(
                                  title: Text(
                                    item.label.isEmpty
                                        ? 'Prefer not to say'
                                        : item.label,
                                    style: AppTypography.bodyLarge(
                                      context,
                                      color: p.textPrimary,
                                      weight: selected
                                          ? FontWeights.extrabold
                                          : FontWeights.semibold,
                                    ),
                                  ),
                                  trailing: selected
                                      ? Icon(Icons.check_circle_rounded,
                                          color: p.accent)
                                      : null,
                                  onTap: () => Navigator.pop(ctx, item.value),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
    query.dispose();
    if (picked != null) onPick(picked);
  }
}

// ─── App bar ────────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  const _GlassAppBar({
    required this.dirty,
    required this.phase,
    required this.successProgress,
    required this.onCancel,
    required this.onSave,
  });

  final bool dirty;
  final _SavePhase phase;
  final Animation<double> successProgress;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final canSave = dirty && phase != _SavePhase.saving;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: (p.isDark ? AppColors.zincBase : p.bg)
                .withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(
                color: p.border.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: p.textSecondary,
                ),
                child: const Text('← Cancel'),
              ),
              Expanded(
                child: Text(
                  'Edit Profile',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge(context, color: p.textPrimary, weight: FontWeights.extrabold),
                ),
              ),
              _SavePill(
                enabled: canSave,
                phase: phase,
                successProgress: successProgress,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavePill extends StatelessWidget {
  const _SavePill({
    required this.enabled,
    required this.phase,
    required this.successProgress,
    required this.onPressed,
  });

  final bool enabled;
  final _SavePhase phase;
  final Animation<double> successProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final saving = phase == _SavePhase.saving;
    final success = phase == _SavePhase.success;

    return AnimatedOpacity(
      duration: Motion.base,
      opacity: enabled || saving || success ? 1 : 0.38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: Radii.brBanner,
          child: Ink(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: Radii.brBanner,
              gradient: enabled || saving || success
                  ? const LinearGradient(
                      colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
                    )
                  : null,
              color: enabled || saving || success
                  ? null
                  : AppColors.inputDarkBorder,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.brandPrimaryHover.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: saving
                    ? Row(
                        key: const ValueKey('saving'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Saving…',
                            style: AppTypography.titleSmall(context, color: AppColors.onAccent, weight: FontWeights.bold),
                          ),
                        ],
                      )
                    : success
                        ? ScaleTransition(
                            key: const ValueKey('ok'),
                            scale: CurvedAnimation(
                              parent: successProgress,
                              curve: Motion.emphasized,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.success,
                              size: 22,
                            ),
                          )
                        : Text(
                            key: const ValueKey('save'),
                            'Save',
                            style: AppTypography.titleSmall(context, color: AppColors.onAccent, weight: FontWeights.bold),
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tabs ───────────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['General', 'Personal', 'Preview'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: 'Profile sections',
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.isDark
              ? AppColors.inputDark.withValues(alpha: 0.85)
              : p.surface2,
          borderRadius: Radii.brBanner,
          border: Border.all(color: p.border.withValues(alpha: 0.6)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / 3;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: Motion.slow,
                  curve: Motion.easeOut,
                  left: slot * index,
                  top: 0,
                  bottom: 0,
                  width: slot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: Radii.brPanel,
                      gradient: const LinearGradient(
                        colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.brandPrimaryHover.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(3, (i) {
                    final selected = i == index;
                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: Radii.brPanel,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.base,
                              style: AppTypography.bodyMedium(context, color: selected
                                    ? AppColors.onAccent
                                    : p.textSecondary, weight: FontWeights.bold),
                              child: Text(_labels[i]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Media ──────────────────────────────────────────────────────────────────

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({
    required this.url,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cover photo',
      child: GestureDetector(
        onTap: onPick,
        onLongPress: url != null
            ? () {
                HapticFeedback.mediumImpact();
                onRemove();
              }
            : null,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: Radii.brBanner,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  child: KeyedSubtree(
                    key: ValueKey(url ?? 'empty'),
                    child: _mediaCover(url),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPick,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.scrim.withValues(alpha: 0.35),
                      border: Border.all(
                        color: AppColors.onAccent.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.scrim.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: AppColors.onAccent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.url,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.profileAvatarGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimaryHover.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: p.isDark
                          ? AppColors.zincSurface
                          : p.surface,
                      child: _mediaAvatar(url, p),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPick,
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
                          ),
                          border: Border.all(
                            color: p.isDark
                                ? AppColors.zincBase
                                : p.bg,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PillButton(
              label: 'Change Photo',
              filled: true,
              onTap: onPick,
            ),
            if (url != null && url!.isNotEmpty) ...[
              const SizedBox(width: 10),
              _PillButton(
                label: 'Remove',
                filled: false,
                danger: true,
                onTap: onRemove,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final bool filled;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brPill,
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: Radii.brPill,
            gradient: filled && !danger
                ? const LinearGradient(
                    colors: [AppColors.brandPrimaryHover, AppColors.fuchsia],
                  )
                : null,
            border: danger
                ? Border.all(color: AppColors.error.withValues(alpha: 0.7))
                : filled
                    ? null
                    : Border.all(color: AppColors.inputDarkBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.bodyMedium(context, color: danger ? AppColors.error : AppColors.onAccent, weight: FontWeights.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Username badge ─────────────────────────────────────────────────────────

class _UsernameBadge extends StatelessWidget {
  const _UsernameBadge({required this.status});

  final _UsernameStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _UsernameStatus.idle:
        return const SizedBox.shrink();
      case _UsernameStatus.checking:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _UsernameStatus.available:
        return const Icon(Icons.check_circle_rounded,
            size: 20, color: AppColors.success);
      case _UsernameStatus.taken:
        return const Icon(Icons.cancel_rounded,
            size: 20, color: AppColors.error);
      case _UsernameStatus.invalid:
        return const Icon(Icons.error_outline_rounded,
            size: 20, color: AppColors.warning);
    }
  }
}

// ─── Preview ────────────────────────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({
    required this.coverUrl,
    required this.avatarUrl,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.hasBio,
    required this.country,
    required this.isPro,
    required this.isVerified,
    required this.joinedLabel,
  });

  final String? coverUrl;
  final String? avatarUrl;
  final String displayName;
  final String username;
  final String bio;
  final bool hasBio;
  final String country;
  final bool isPro;
  final bool isVerified;
  final String joinedLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final card = p.isDark ? AppColors.zincSurface : p.surface;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: Radii.brSheet,
        border: Border.all(color: p.border.withValues(alpha: 0.8)),
        boxShadow: Elevations.raised(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: _mediaCover(coverUrl),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.profileAvatarGradient,
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: card,
                      child: _mediaAvatar(avatarUrl, p),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineSmall(context, color: p.textPrimary, weight: FontWeights.black),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: CategoryColors.dev.accentOf(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: AppTypography.bodyLarge(
                    context,
                    color: AppColors.brandPrimaryHover,
                    weight: FontWeights.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge(
                      context,
                      color: hasBio ? p.textSecondary : p.textMuted,
                    ).copyWith(height: 1.4),
                  ),
                ),
                if (country.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    country,
                    style: AppTypography.bodyMedium(context, color: p.textMuted, weight: FontWeights.semibold),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  joinedLabel,
                  style: AppTypography.labelMedium(context, color: p.textMuted),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: const [
                      Expanded(
                        child: _StatCell(value: '—', label: 'Followers'),
                      ),
                      Expanded(
                        child: _StatCell(value: '—', label: 'Following'),
                      ),
                      Expanded(
                        child: _StatCell(value: '128+', label: 'Tools'),
                      ),
                    ],
                  ),
                ),
                if (isPro) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: Radii.brPill,
                      gradient: AppColors.goldGradient,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 16, color: AppColors.lightTextPrimary),
                        SizedBox(width: 6),
                        Text(
                          'Farvixo Pro',
                          style: AppTypography.labelMedium(context, color: AppColors.lightTextPrimary, weight: FontWeights.extrabold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'This is how others see you',
                  style: AppTypography.labelMedium(context, color: p.textMuted, weight: FontWeights.medium),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMedium(context, color: p.textPrimary, weight: FontWeights.black),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall(context, color: p.textMuted, weight: FontWeights.semibold),
        ),
      ],
    );
  }
}

// ─── Media helpers ──────────────────────────────────────────────────────────

Widget _mediaCover(String? url) {
  if (url != null && url.isNotEmpty) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverGradient(),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _coverGradient(),
    );
  }
  return _coverGradient();
}

Widget _coverGradient() {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        colors: AppColors.profileHeroGradient.colors,
      ),
    ),
  );
}

Widget _mediaAvatar(String? url, AppPalette p) {
  if (url != null && url.isNotEmpty) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person_rounded, color: p.accent, size: 40),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          Icon(Icons.person_rounded, color: p.accent, size: 40),
    );
  }
  return Icon(Icons.person_rounded, color: p.accent, size: 40);
}

// ─── Picker data ────────────────────────────────────────────────────────────

class _PickerItem {
  const _PickerItem({required this.label, required this.value});
  final String label;
  final String value;
}

const _kCountries = <(String, String)>[
  ('🇧🇩', 'Bangladesh'),
  ('🇮🇳', 'India'),
  ('🇺🇸', 'United States'),
  ('🇬🇧', 'United Kingdom'),
  ('🇨🇦', 'Canada'),
  ('🇦🇺', 'Australia'),
  ('🇩🇪', 'Germany'),
  ('🇫🇷', 'France'),
  ('🇯🇵', 'Japan'),
  ('🇰🇷', 'South Korea'),
  ('🇸🇬', 'Singapore'),
  ('🇦🇪', 'United Arab Emirates'),
  ('🇸🇦', 'Saudi Arabia'),
  ('🇵🇰', 'Pakistan'),
  ('🇳🇵', 'Nepal'),
  ('🇱🇰', 'Sri Lanka'),
  ('🇧🇷', 'Brazil'),
  ('🇲🇽', 'Mexico'),
  ('🇪🇸', 'Spain'),
  ('🇮🇹', 'Italy'),
  ('🇳🇱', 'Netherlands'),
  ('🇸🇪', 'Sweden'),
  ('🇳🇴', 'Norway'),
  ('🇩🇰', 'Denmark'),
  ('🇫🇮', 'Finland'),
  ('🇨🇭', 'Switzerland'),
  ('🇦🇹', 'Austria'),
  ('🇧🇪', 'Belgium'),
  ('🇮🇪', 'Ireland'),
  ('🇳🇿', 'New Zealand'),
  ('🇿🇦', 'South Africa'),
  ('🇳🇬', 'Nigeria'),
  ('🇪🇬', 'Egypt'),
  ('🇹🇷', 'Turkey'),
  ('🇮🇩', 'Indonesia'),
  ('🇲🇾', 'Malaysia'),
  ('🇹🇭', 'Thailand'),
  ('🇵🇭', 'Philippines'),
  ('🇻🇳', 'Vietnam'),
  ('🇨🇳', 'China'),
  ('🇹🇼', 'Taiwan'),
  ('🇭🇰', 'Hong Kong'),
  ('🇦🇷', 'Argentina'),
  ('🇨🇱', 'Chile'),
  ('🇨🇴', 'Colombia'),
  ('🇵🇱', 'Poland'),
  ('🇵🇹', 'Portugal'),
  ('🇬🇷', 'Greece'),
  ('🇷🇺', 'Russia'),
  ('🇺🇦', 'Ukraine'),
];

const _kExtraLanguages = <_PickerItem>[
  _PickerItem(label: 'Portuguese · Português', value: 'Portuguese'),
  _PickerItem(label: 'French · Français', value: 'French'),
  _PickerItem(label: 'German · Deutsch', value: 'German'),
  _PickerItem(label: 'Japanese · 日本語', value: 'Japanese'),
  _PickerItem(label: 'Korean · 한국어', value: 'Korean'),
  _PickerItem(label: 'Turkish · Türkçe', value: 'Turkish'),
];

const _kTimezones = <String>[
  'UTC',
  'Asia/Dhaka',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Asia/Seoul',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Sao_Paulo',
  'Australia/Sydney',
  'Pacific/Auckland',
];

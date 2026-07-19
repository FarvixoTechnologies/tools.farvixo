import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/profile_details.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_details_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../utils/validators.dart';
import '../../widgets/premium_kit.dart';

/// Full-screen editable profile — PROFILE_PAGE.md 2026 Enterprise Edition.
/// Tabs: General · Personal · Preview
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ProfileDetails _draft;
  late ProfileDetails _baseline;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _dirty = false;

  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _bio = TextEditingController();
  final _country = TextEditingController();
  final _language = TextEditingController();
  final _birthday = TextEditingController();
  final _gender = TextEditingController();
  final _website = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
    _country.text = current.country;
    _language.text = current.language;
    _birthday.text = current.birthday;
    _gender.text = current.gender;
    _website.text = current.website;

    for (final c in _allControllers) {
      c.addListener(_onChanged);
    }
  }

  List<TextEditingController> get _allControllers => [
        _username,
        _fullName,
        _bio,
        _country,
        _language,
        _birthday,
        _gender,
        _website,
      ];

  void _onChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  ProfileDetails _collect() {
    final name = _fullName.text.trim();
    return _draft.copyWith(
      username: _username.text.trim().replaceFirst(RegExp(r'^@'), ''),
      displayName: name,
      bio: _bio.text.trim(),
      country: _country.text.trim(),
      language: _language.text.trim(),
      birthday: _birthday.text.trim(),
      gender: _gender.text.trim(),
      website: _website.text.trim(),
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
    setState(() {
      _dirty = true;
      _draft = cover
          ? _draft.copyWith(coverUrl: file.path)
          : _draft.copyWith(avatarUrl: file.path);
    });
  }

  void _undo() {
    setState(() {
      _draft = _baseline;
      _username.text = _baseline.username;
      _fullName.text = _baseline.displayName;
      _bio.text = _baseline.bio;
      _country.text = _baseline.country;
      _language.text = _baseline.language;
      _birthday.text = _baseline.birthday;
      _gender.text = _baseline.gender;
      _website.text = _baseline.website;
      _dirty = false;
    });
  }

  Future<void> _save({bool pop = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _tabs.animateTo(0);
      return;
    }
    setState(() => _saving = true);
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
      _saving = false;
      _baseline = next;
      _draft = next;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (pop && mounted) Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final p = AppPalette.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unsaved changes',
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Save before leaving?',
            style: TextStyle(color: p.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Discard', style: TextStyle(color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('Stay', style: TextStyle(color: p.textSecondary)),
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
      return true;
    }
    return action == 'discard';
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PremiumBackground(
          child: SafeArea(
            child: Column(
              children: [
                _EditorAppBar(
                  dirty: _dirty,
                  saving: _saving,
                  onCancel: () async {
                    final ok = await _onWillPop();
                    if (ok && context.mounted) Navigator.of(context).pop();
                  },
                  onUndo: _dirty ? _undo : null,
                  onSave: () => _save(),
                ),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  labelColor: p.accent,
                  unselectedLabelColor: p.textMuted,
                  indicatorColor: p.accent,
                  tabs: const [
                    Tab(text: 'General'),
                    Tab(text: 'Personal'),
                    Tab(text: 'Preview'),
                  ],
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: TabBarView(
                      controller: _tabs,
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [child],
      );

  Widget _generalTab(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaPickers(
          avatarUrl: _draft.avatarUrl,
          coverUrl: _draft.coverUrl,
          onPickAvatar: () => _pickImage(cover: false),
          onPickCover: () => _pickImage(cover: true),
          onRemoveAvatar: () => setState(() {
            _dirty = true;
            _draft = _draft.copyWith(clearAvatar: true);
          }),
          onRemoveCover: () => setState(() {
            _dirty = true;
            _draft = _draft.copyWith(clearCover: true);
          }),
        ),
        const SizedBox(height: 16),
        _field(
          controller: _fullName,
          label: 'Full Name',
          icon: Icons.badge_outlined,
        ),
        _field(
          controller: _username,
          label: 'Username',
          icon: Icons.alternate_email_rounded,
          prefix: '@',
          validator: Validators.username,
        ),
        _field(
          controller: _bio,
          label: 'Bio',
          icon: Icons.notes_rounded,
          maxLines: 4,
          hint: 'Tell the world who you are…',
        ),
      ],
    );
  }

  Widget _personalTab(AppPalette p) {
    return Column(
      children: [
        _field(controller: _country, label: 'Country', icon: Icons.public_rounded),
        _field(controller: _language, label: 'Language', icon: Icons.translate_rounded),
        _field(
          controller: _birthday,
          label: 'Birthday',
          icon: Icons.cake_outlined,
          hint: 'YYYY-MM-DD',
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(now.year - 20),
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (picked != null) {
              _birthday.text =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
        ),
        _field(
          controller: _gender,
          label: 'Gender (Optional)',
          icon: Icons.wc_rounded,
        ),
        _field(
          controller: _website,
          label: 'Website',
          icon: Icons.language_rounded,
          validator: Validators.website,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _previewTab(AppPalette p) {
    final draft = _collect();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: _coverPreview(draft.coverUrl, p),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Column(
              children: [
                _avatarPreview(draft.avatarUrl, p, 72),
                const SizedBox(height: 10),
                Text(
                  draft.displayName.isEmpty ? 'Your Name' : draft.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  '@${draft.username.isEmpty ? 'username' : draft.username}',
                  style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  draft.hasBio ? draft.bio : 'No bio yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: draft.hasBio ? p.textSecondary : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? prefix,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          prefixIcon: Icon(icon, color: p.textMuted, size: 20),
          filled: true,
          fillColor: p.surface.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.dirty,
    required this.saving,
    required this.onCancel,
    required this.onUndo,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onUndo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text('Cancel', style: TextStyle(color: p.textSecondary)),
          ),
          const Spacer(),
          Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          if (onUndo != null)
            IconButton(
              tooltip: 'Undo',
              onPressed: onUndo,
              icon: Icon(Icons.undo_rounded, color: p.textSecondary),
            ),
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(dirty ? 'Save' : 'Done'),
          ),
        ],
      ),
    );
  }
}

class _MediaPickers extends StatelessWidget {
  const _MediaPickers({
    required this.avatarUrl,
    required this.coverUrl,
    required this.onPickAvatar,
    required this.onPickCover,
    required this.onRemoveAvatar,
    required this.onRemoveCover,
  });

  final String? avatarUrl;
  final String? coverUrl;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;
  final VoidCallback onRemoveAvatar;
  final VoidCallback onRemoveCover;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: _coverPreview(coverUrl, p),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Row(
                children: [
                  _miniBtn(Icons.photo_outlined, onPickCover),
                  if (coverUrl != null) ...[
                    const SizedBox(width: 6),
                    _miniBtn(Icons.delete_outline, onRemoveCover),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _avatarPreview(avatarUrl, p, 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile Picture',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: p.textPrimary)),
                  Text('Crop & compress on upload',
                      style: TextStyle(fontSize: 12, color: p.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: onPickAvatar,
                        child: const Text('Change'),
                      ),
                      if (avatarUrl != null)
                        TextButton(
                          onPressed: onRemoveAvatar,
                          child: Text('Remove',
                              style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

Widget _coverPreview(String? url, AppPalette p) {
  if (url != null && url.isNotEmpty) {
    if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _coverGradient(p));
    }
    return Image.file(File(url), fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverGradient(p));
  }
  return _coverGradient(p);
}

Widget _coverGradient(AppPalette p) {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          p.accent,
          Color.lerp(p.accent, AppColors.brandMagenta, 0.6)!,
          AppColors.brandMagenta,
        ],
      ),
    ),
  );
}

Widget _avatarPreview(String? url, AppPalette p, double size) {
  Widget child;
  if (url != null && url.isNotEmpty) {
    if (url.startsWith('http')) {
      child = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(Icons.person, color: p.accent));
    } else {
      child = Image.file(File(url), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(Icons.person, color: p.accent));
    }
  } else {
    child = Icon(Icons.person, color: p.accent, size: size * 0.45);
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.goldPremium, width: 2.5),
      boxShadow: [
        BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 12),
      ],
    ),
    child: ClipOval(
      child: ColoredBox(color: p.surface, child: child),
    ),
  );
}

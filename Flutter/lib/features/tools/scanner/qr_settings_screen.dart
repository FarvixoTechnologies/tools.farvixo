import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium_kit.dart';
import 'data/scan_history_repository.dart';
import 'providers/qr_settings_provider.dart';
import 'providers/scan_history_providers.dart';
import 'services/qr_export_io.dart';

/// Scanner & privacy settings for the QR module. Persists to SharedPreferences
/// via [qrSettingsProvider]; privacy actions (retention / clear) act on the
/// encrypted Hive store. Reuses the Farvixo premium kit.
class QrSettingsScreen extends ConsumerWidget {
  const QrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(qrSettingsProvider);
    final notifier = ref.read(qrSettingsProvider.notifier);
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.md, Insets.sm, Insets.md, 0),
                child: FadeSlideIn(
                  child: PremiumHeader(
                    title: 'Scanner Settings',
                    subtitle: 'Behaviour & privacy',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      Insets.md, Insets.md, Insets.md, Insets.xxl),
                  children: [
                    FadeSlideIn(
                      index: 1,
                      child: _Group(
                        title: 'Scanning',
                        children: [
                          _SwitchTile(
                            icon: Icons.volume_up_rounded,
                            title: 'Scan sound',
                            subtitle: 'Play a click on a successful scan',
                            value: s.sound,
                            onChanged: notifier.setSound,
                          ),
                          _SwitchTile(
                            icon: Icons.vibration_rounded,
                            title: 'Vibration',
                            subtitle: 'Haptic feedback on detection',
                            value: s.vibration,
                            onChanged: notifier.setVibration,
                          ),
                          _SwitchTile(
                            icon: Icons.open_in_new_rounded,
                            title: 'Auto-open safe links',
                            subtitle: 'Skip the result screen for trusted URLs',
                            value: s.autoOpenLinks,
                            onChanged: notifier.setAutoOpenLinks,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    FadeSlideIn(
                      index: 2,
                      child: _Group(
                        title: 'Privacy',
                        children: [
                          _SwitchTile(
                            icon: Icons.visibility_off_rounded,
                            title: 'Private mode',
                            subtitle: 'Scan without saving to history',
                            value: s.privateMode,
                            onChanged: notifier.setPrivateMode,
                          ),
                          _SwitchTile(
                            icon: Icons.cloud_off_rounded,
                            title: 'Offline-only',
                            subtitle: 'Never use network reputation lookups',
                            value: s.offlineOnly,
                            onChanged: notifier.setOfflineOnly,
                          ),
                          _SwitchTile(
                            icon: Icons.fingerprint_rounded,
                            title: 'Lock history',
                            subtitle: 'Require device auth to open history',
                            value: s.biometricLock,
                            onChanged: notifier.setBiometricLock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    FadeSlideIn(
                      index: 3,
                      child: _Group(
                        title: 'Data',
                        children: [
                          _RetentionTile(
                            value: s.retentionDays,
                            onChanged: (days) async {
                              notifier.setRetentionDays(days);
                              if (days > 0) {
                                final repo = await ref
                                    .read(scanHistoryRepositoryProvider.future);
                                await repo.purgeOlderThan(Duration(days: days));
                              }
                            },
                          ),
                          _ActionTile(
                            icon: Icons.table_chart_rounded,
                            title: 'Export as CSV',
                            subtitle: 'Share a spreadsheet of your scans',
                            onTap: () => _run(context, ref,
                                (repo) => QrExportIo.exportCsv(repo)),
                          ),
                          _ActionTile(
                            icon: Icons.backup_rounded,
                            title: 'Export backup (JSON)',
                            subtitle: 'Full backup incl. favorites & trash',
                            onTap: () => _run(context, ref,
                                (repo) => QrExportIo.exportJsonBackup(repo)),
                          ),
                          _ActionTile(
                            icon: Icons.restore_rounded,
                            title: 'Import backup',
                            subtitle: 'Merge scans from a JSON backup',
                            onTap: () => _import(context, ref),
                          ),
                          _DangerTile(
                            icon: Icons.delete_forever_rounded,
                            title: 'Clear all history',
                            onTap: () => _confirmClear(context, ref),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Your scan history is encrypted and stored only on this '
                      'device. Nothing is uploaded and there is no tracking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: p.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(ScanHistoryRepository repo) action,
  ) async {
    try {
      final repo = await ref.read(scanHistoryRepositoryProvider.future);
      await action(repo);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final repo = await ref.read(scanHistoryRepositoryProvider.future);
      final count = await QrExportIo.importJsonBackup(repo);
      if (count != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Imported $count scan${count == 1 ? '' : 's'}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Import failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final p = AppPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brPanel),
        title: Text('Clear all history?',
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('This permanently deletes every saved scan on this device.',
            style: TextStyle(color: p.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(scanHistoryRepositoryProvider.future);
    await repo.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('History cleared'),
        ),
      );
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, Insets.sm),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: p.textMuted,
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm, vertical: Insets.xs),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      secondary: Icon(icon, color: p.accent),
      title: Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: p.textMuted)),
    );
  }
}

class _RetentionTile extends StatelessWidget {
  const _RetentionTile({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [0, 7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm, vertical: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_delete_rounded, color: p.accent),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-delete history',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary)),
                    Text('Remove scans older than the selected window',
                        style: TextStyle(fontSize: 12, color: p.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            children: [
              for (final o in _options)
                ChoiceChip(
                  label: Text(o == 0 ? 'Off' : '$o days'),
                  selected: value == o,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onChanged(o);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      leading: Icon(icon, color: p.accent),
      title: Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: p.textMuted)),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      leading: Icon(icon, color: AppColors.error),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
    );
  }
}

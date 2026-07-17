import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../services/device_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/premium_kit.dart';

final _devicesProvider = FutureProvider.autoDispose<List<UserDevice>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DeviceService.instance.list(storage: storage);
});

/// Settings › Devices & Active Sessions
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_devicesProvider);
    final p = AppPalette.of(context);

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: PremiumHeader(
                  title: 'Devices',
                  subtitle: 'Active sessions on your account',
                  emoji: '📱',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/settings'),
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Could not load devices',
                        style: TextStyle(color: p.textSecondary)),
                  ),
                  data: (devices) {
                    if (devices.isEmpty) {
                      return Center(
                        child: Text(
                          'No devices registered yet.\nSign in online to sync.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: devices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final d = devices[i];
                        return GlassCard(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: d.isCurrent
                                  ? AppColors.brandPrimary.withValues(alpha: .2)
                                  : p.surface2,
                              child: Icon(
                                Icons.devices_rounded,
                                color: d.isCurrent
                                    ? AppColors.brandPrimaryHover
                                    : p.textSecondary,
                              ),
                            ),
                            title: Text(
                              d.deviceName ?? 'Unknown device',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                if (d.platform != null) d.platform!,
                                if (d.isCurrent) 'This device',
                                'Last active ${_fmt(d.lastActive)}',
                              ].join(' · '),
                              style: TextStyle(
                                  fontSize: 12, color: p.textSecondary),
                            ),
                            trailing: d.isCurrent
                                ? const Chip(
                                    label: Text('Current',
                                        style: TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : IconButton(
                                    tooltip: 'Revoke',
                                    icon: const Icon(Icons.logout_rounded),
                                    onPressed: () async {
                                      final storage =
                                          ref.read(storageServiceProvider);
                                      await DeviceService.instance.revoke(
                                        d.id,
                                        storage: storage,
                                      );
                                      ref.invalidate(_devicesProvider);
                                    },
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 2) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

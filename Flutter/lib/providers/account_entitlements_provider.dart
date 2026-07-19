import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/farvixo_api_client.dart';
import 'auth_provider.dart';

/// Account plan / credits / storage shown across Settings and Profile.
@immutable
class AccountEntitlements {
  const AccountEntitlements({
    required this.plan,
    required this.planLabel,
    required this.creditsUsed,
    required this.creditsMax,
    required this.storageUsedGb,
    required this.storageMaxGb,
    this.renewDateLabel,
    this.isGuest = true,
    this.billingConfigured = false,
  });

  final String plan;
  final String planLabel;
  final int creditsUsed;
  final int creditsMax;
  final double storageUsedGb;
  final double storageMaxGb;
  final String? renewDateLabel;
  final bool isGuest;
  final bool billingConfigured;

  int get creditsLeft => (creditsMax - creditsUsed).clamp(0, creditsMax);

  String get creditsLabel => '$creditsLeft / $creditsMax';

  String get storageLabel =>
      '${storageUsedGb.toStringAsFixed(storageUsedGb < 10 ? 1 : 0)} / ${storageMaxGb.toStringAsFixed(0)} GB';

  String get hubSubscriptionSubtitle {
    if (isGuest) return 'Guest · sign in for credits';
    return '$planLabel plan · $creditsLeft credits left';
  }

  AccountEntitlements copyWith({
    String? plan,
    String? planLabel,
    int? creditsUsed,
    int? creditsMax,
    double? storageUsedGb,
    double? storageMaxGb,
    String? renewDateLabel,
    bool? isGuest,
    bool? billingConfigured,
  }) {
    return AccountEntitlements(
      plan: plan ?? this.plan,
      planLabel: planLabel ?? this.planLabel,
      creditsUsed: creditsUsed ?? this.creditsUsed,
      creditsMax: creditsMax ?? this.creditsMax,
      storageUsedGb: storageUsedGb ?? this.storageUsedGb,
      storageMaxGb: storageMaxGb ?? this.storageMaxGb,
      renewDateLabel: renewDateLabel ?? this.renewDateLabel,
      isGuest: isGuest ?? this.isGuest,
      billingConfigured: billingConfigured ?? this.billingConfigured,
    );
  }

  factory AccountEntitlements.fromUser(AppUser? user) {
    final isGuest = user == null || user.isGuest;
    final plan = (user?.plan ?? 'free').toLowerCase();
    final isPro = plan == 'pro' || plan == 'enterprise';
    final planLabel = switch (plan) {
      'enterprise' => 'Enterprise',
      'pro' => 'Pro',
      _ => 'Free',
    };

    if (isGuest) {
      return const AccountEntitlements(
        plan: 'guest',
        planLabel: 'Guest',
        creditsUsed: 0,
        creditsMax: 10,
        storageUsedGb: 0,
        storageMaxGb: 0.5,
        renewDateLabel: null,
        isGuest: true,
        billingConfigured: false,
      );
    }

    if (isPro) {
      return AccountEntitlements(
        plan: plan,
        planLabel: planLabel,
        creditsUsed: 0,
        creditsMax: 10000,
        storageUsedGb: 0,
        storageMaxGb: 100,
        renewDateLabel: null,
        isGuest: false,
        billingConfigured: false,
      );
    }

    return const AccountEntitlements(
      plan: 'free',
      planLabel: 'Free',
      creditsUsed: 0,
      creditsMax: 500,
      storageUsedGb: 0,
      storageMaxGb: 0.5,
      renewDateLabel: null,
      isGuest: false,
      billingConfigured: false,
    );
  }

  factory AccountEntitlements.fromBillingStatus(
    Map<String, dynamic> data, {
    required AppUser user,
  }) {
    final plan = (data['plan'] as String? ?? user.plan).toLowerCase();
    final planLabel = data['planLabel'] as String? ??
        switch (plan) {
          'enterprise' => 'Enterprise',
          'pro' => 'Pro',
          _ => 'Free',
        };
    final credits = (data['credits'] as num?)?.toInt() ?? 0;
    final creditsMax = (data['creditsMax'] as num?)?.toInt() ??
        (plan == 'pro' || plan == 'enterprise' ? 10000 : 500);
    final storageUsed =
        (data['storageUsedGb'] as num?)?.toDouble() ?? 0;
    final storageMax = (data['storageMaxGb'] as num?)?.toDouble() ??
        (plan == 'pro' || plan == 'enterprise' ? 100 : 0.5);
    final renewRaw = data['renewDate'] as String?;
    String? renewLabel;
    if (renewRaw != null && renewRaw.isNotEmpty) {
      final dt = DateTime.tryParse(renewRaw);
      if (dt != null) {
        renewLabel =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }
    // credits in API is remaining balance; UI shows left/max.
    final creditsUsed = (creditsMax - credits).clamp(0, creditsMax);

    return AccountEntitlements(
      plan: plan,
      planLabel: planLabel,
      creditsUsed: creditsUsed,
      creditsMax: creditsMax,
      storageUsedGb: storageUsed,
      storageMaxGb: storageMax,
      renewDateLabel: renewLabel,
      isGuest: false,
      billingConfigured: data['billingConfigured'] == true,
    );
  }
}

/// Local defaults from auth user; refreshed by [accountEntitlementsRemoteProvider].
final accountEntitlementsProvider = Provider<AccountEntitlements>((ref) {
  final user = ref.watch(authProvider);
  final remote = ref.watch(accountEntitlementsRemoteProvider);
  return remote.maybeWhen(
    data: (e) => e,
    orElse: () => AccountEntitlements.fromUser(user),
  );
});

/// Fetches `/billing/status` when signed in.
final accountEntitlementsRemoteProvider =
    FutureProvider<AccountEntitlements>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.isGuest) {
    return AccountEntitlements.fromUser(user);
  }
  final client = FarvixoApiClient();
  if (!client.hasSession) {
    return AccountEntitlements.fromUser(user);
  }
  final res = await client.get('/billing/status');
  if (!res.ok || res.data == null) {
    return AccountEntitlements.fromUser(user);
  }
  return AccountEntitlements.fromBillingStatus(res.data!, user: user);
});

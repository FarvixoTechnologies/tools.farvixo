import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// The payload categories a scanned/decoded QR (or barcode) can resolve to.
///
/// Kept intentionally small and grounded in what the offline parser can
/// reliably recognise — every value here is produced by [QrParser] and has a
/// matching branch in the result UI. Colors reuse the existing category tokens
/// from [AppColors] so the module needs no new theme surface.
enum QrType {
  url,
  wifi,
  contact,
  email,
  sms,
  phone,
  geo,
  event,
  upi,
  crypto,
  appLink,
  text;

  /// Short human label for chips / headers.
  String get label => switch (this) {
        QrType.url => 'Link',
        QrType.wifi => 'Wi-Fi',
        QrType.contact => 'Contact',
        QrType.email => 'Email',
        QrType.sms => 'SMS',
        QrType.phone => 'Phone',
        QrType.geo => 'Location',
        QrType.event => 'Event',
        QrType.upi => 'Payment',
        QrType.crypto => 'Crypto',
        QrType.appLink => 'App Link',
        QrType.text => 'Text',
      };

  IconData get icon => switch (this) {
        QrType.url => Icons.link_rounded,
        QrType.wifi => Icons.wifi_rounded,
        QrType.contact => Icons.person_rounded,
        QrType.email => Icons.mail_rounded,
        QrType.sms => Icons.sms_rounded,
        QrType.phone => Icons.phone_rounded,
        QrType.geo => Icons.location_on_rounded,
        QrType.event => Icons.event_rounded,
        QrType.upi => Icons.payments_rounded,
        QrType.crypto => Icons.currency_bitcoin_rounded,
        QrType.appLink => Icons.apps_rounded,
        QrType.text => Icons.notes_rounded,
      };

  /// Accent color drawn from existing brand/category tokens.
  Color get accent => switch (this) {
        QrType.url => AppColors.accentDev,
        QrType.wifi => AppColors.accentDev,
        QrType.contact => AppColors.brandPrimaryHover,
        QrType.email => AppColors.accentAi,
        QrType.sms => AppColors.accentImage,
        QrType.phone => AppColors.accentImage,
        QrType.geo => AppColors.accentAudio,
        QrType.event => AppColors.accentVideo,
        QrType.upi => AppColors.success,
        QrType.crypto => AppColors.goldPremium,
        QrType.appLink => AppColors.brandMagenta,
        QrType.text => AppColors.accentUtility,
      };
}

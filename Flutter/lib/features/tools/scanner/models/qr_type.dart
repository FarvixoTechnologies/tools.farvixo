import 'package:flutter/material.dart';

import '../../../../theme/category_colors.dart';

/// The payload categories a scanned/decoded QR (or barcode) can resolve to.
///
/// Kept intentionally small and grounded in what the offline parser can
/// reliably recognise — every value here is produced by [QrParser] and has a
/// matching branch in the result UI. Colours resolve through [CategoryColors]
/// so the module needs no theme surface of its own and adapts to light mode.
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

  /// The category identity this payload type borrows its colour from.
  CategoryIdentity get identity => switch (this) {
        QrType.url || QrType.wifi => CategoryColors.dev,
        QrType.contact => CategoryColors.brand,
        QrType.email => CategoryColors.ai,
        QrType.sms || QrType.phone => CategoryColors.image,
        QrType.geo => CategoryColors.audio,
        QrType.event => CategoryColors.video,
        QrType.crypto => CategoryColors.premium,
        QrType.appLink => CategoryColors.favorite,
        QrType.upi => CategoryColors.finance,
        QrType.text => CategoryColors.utility,
      };

  /// Theme-aware accent for this payload type.
  Color accentOf(BuildContext context) => identity.accentOf(context);
}

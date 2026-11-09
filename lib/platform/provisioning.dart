// provisioning.dart — when a sideloaded iOS build stops launching.
//
// A free-Apple-ID sideload (Sideloadly, AltStore) is re-signed every 7 days.
// Once the profile lapses iOS refuses to open the app at all, so background
// sync stops and nights wait in the band until it is re-signed. The native side
// (ProvisioningBridge in ios/Runner/AppDelegate.swift) reads the profile's
// ExpirationDate; App Store / TestFlight builds carry no profile and answer null,
// which turns every part of this off.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../notify/notification_center.dart';
import '../notify/notification_event.dart';

/// Warn this far ahead. A day of notice covers one missed evening, and the
/// re-sign itself is a minute with a cable.
const Duration kSideloadWarnAhead = Duration(hours: 48);

/// Notify (rather than only show the Home card) inside this window.
const Duration kSideloadNotifyAhead = Duration(hours: 24);

class Provisioning {
  Provisioning._();

  static const _ch = MethodChannel('openstrap/provisioning');

  /// Test seam; null runs the platform channel.
  static Future<DateTime?> Function()? debugExpiry;

  /// The install's signing expiry, or null (not iOS, no profile, or unknown).
  /// Never throws.
  static Future<DateTime?> expiry() async {
    final hook = debugExpiry;
    if (hook != null) return hook();
    if (!Platform.isIOS) return null;
    try {
      final ms = await _ch.invokeMethod<int>('expiryMs');
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }
}

/// What to say about [expiry] at [now]: null when there is nothing to say
/// (no profile, or more than [kSideloadWarnAhead] away). [hoursLeft] is 0 once
/// it has lapsed — the app is running only because iOS has not re-checked yet.
({int hoursLeft, bool notify})? sideloadExpiryNotice(
    DateTime? expiry, DateTime now) {
  if (expiry == null) return null;
  final left = expiry.difference(now);
  if (left > kSideloadWarnAhead) return null;
  final hours = left.isNegative ? 0 : left.inHours;
  return (hoursLeft: hours, notify: left <= kSideloadNotifyAhead);
}

/// One notification per expiry date, through the single emitter. Safe to call
/// from every foreground open and background wake: the dedupe key carries the
/// expiry, so a re-signed build (new expiry) can warn again next week.
Future<bool> checkSideloadExpiry({bool allowPermissionPrompt = false}) async {
  try {
    final expiry = await Provisioning.expiry();
    final notice = sideloadExpiryNotice(expiry, DateTime.now());
    if (expiry == null || notice == null || !notice.notify) return false;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final stamp = expiry.toIso8601String().substring(0, 10);
    return NotificationCenter.instance.emit(
      NotificationEvent(
        dedupeKey: '$stamp:sideload_expiry',
        category: NotifCategory.device,
        title: 'Re-sign OpenStrap soon',
        body: 'This install stops opening within a day. Re-sign it with '
            'Sideloadly to keep syncing.',
        date: day,
        route: '/today',
      ),
      allowPermissionPrompt: allowPermissionPrompt,
    );
  } catch (_) {
    return false;
  }
}

// A sideloaded iOS build stops opening when its 7-day profile lapses, and with
// it background sync. The card and notification must say so in time, once per
// expiry, and stay silent on builds that have no profile at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openstrap_edge/notify/notification_center.dart';
import 'package:openstrap_edge/notify/notification_event.dart';
import 'package:openstrap_edge/platform/provisioning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sideloadExpiryNotice', () {
    final now = DateTime(2026, 11, 9, 12);

    test('no profile, or far away, says nothing', () {
      expect(sideloadExpiryNotice(null, now), isNull);
      expect(sideloadExpiryNotice(now.add(const Duration(days: 6)), now),
          isNull);
      expect(sideloadExpiryNotice(now.add(const Duration(hours: 49)), now),
          isNull);
    });

    test('inside two days it shows; inside one it also notifies', () {
      expect(sideloadExpiryNotice(now.add(const Duration(hours: 30)), now),
          (hoursLeft: 30, notify: false));
      expect(sideloadExpiryNotice(now.add(const Duration(hours: 10)), now),
          (hoursLeft: 10, notify: true));
    });

    test('a lapsed profile reads as zero hours, never negative', () {
      expect(sideloadExpiryNotice(now.subtract(const Duration(hours: 3)), now),
          (hoursLeft: 0, notify: true));
    });
  });

  group('checkSideloadExpiry', () {
    final sent = <NotificationEvent>[];
    final originalSink = NotificationCenter.instance.presentSink;

    setUp(() {
      sent.clear();
      // Quiet hours off, so the result does not depend on when CI runs.
      SharedPreferences.setMockInitialValues({'notif_quiet_enabled': false});
      NotificationCenter.instance.presentSink =
          (NotificationEvent e, {bool allowPermissionPrompt = true}) async {
        sent.add(e);
        return true;
      };
    });
    tearDown(() {
      NotificationCenter.instance.presentSink = originalSink;
      Provisioning.debugExpiry = null;
    });

    test('no profile never notifies', () async {
      Provisioning.debugExpiry = () async => null;
      expect(await checkSideloadExpiry(), isFalse);
      expect(sent, isEmpty);
    });

    test('two days out shows the card but does not notify', () async {
      Provisioning.debugExpiry =
          () async => DateTime.now().add(const Duration(hours: 40));
      expect(await checkSideloadExpiry(), isFalse);
      expect(sent, isEmpty);
    });

    test('within a day it notifies once per expiry', () async {
      final expiry = DateTime.now().add(const Duration(hours: 6));
      Provisioning.debugExpiry = () async => expiry;
      expect(await checkSideloadExpiry(), isTrue);
      expect(await checkSideloadExpiry(), isFalse, reason: 'same expiry');
      expect(sent, hasLength(1));
      expect(sent.single.category, NotifCategory.device);
      expect(sent.single.dedupeKey,
          '${expiry.toIso8601String().substring(0, 10)}:sideload_expiry');
    });
  });
}

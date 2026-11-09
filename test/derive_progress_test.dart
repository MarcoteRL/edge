// The derive card's "day 3 of 12" comes off DeriveCoordinator.progress. A
// count left behind after a pass (or a throw) would keep an old "day 11 of 12"
// on the next card — the sticky-latch shape AGENTS.md §4.3 warns about.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/compute/profile.dart';
import 'package:openstrap_edge/state/derive_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DeriveCoordinator make() => DeriveCoordinator(
        derive: () => throw StateError('derive should stay lazy'),
        profile: () => const Profile(),
        repo: () => null,
        background: () => false,
        disposed: () => false,
        log: (_) {},
        notify: () {},
        refreshPhoneStepsToday: () async {},
        maybeNotifyRecoveryReady: () async {},
        runHealthExport: () async => 0,
        healthSyncEnabled: () => false,
        telemetryConsent: () => false,
        healthShareConsent: () => false,
        maybeReclaimDiskSpace: () async {},
      );

  test('progress follows the days and is cleared when the pass ends', () async {
    final coordinator = make();
    addTearDown(coordinator.dispose);
    expect(coordinator.progress, (done: 0, total: 0));

    final hold = Completer<void>();
    final seen = <({int done, int total})>[];
    coordinator.debugDeriveRun = (profile, {heavy = false, onDayDone}) async {
      for (var i = 1; i <= 3; i++) {
        onDayDone?.call('2026-11-0$i', i, 3);
        seen.add(coordinator.progress);
      }
      await hold.future;
      return 3;
    };
    final pass = coordinator.afterDrain();
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      (done: 1, total: 3),
      (done: 2, total: 3),
      (done: 3, total: 3),
    ]);
    hold.complete();
    await pass;
    expect(coordinator.progress, (done: 0, total: 0));
  });

  test('a pass that throws does not leave its count behind', () async {
    final coordinator = make();
    addTearDown(coordinator.dispose);
    coordinator.debugDeriveRun = (profile, {heavy = false, onDayDone}) async {
      onDayDone?.call('2026-11-01', 1, 5);
      throw StateError('boom');
    };
    await coordinator.afterDrain();
    expect(coordinator.progress, (done: 0, total: 0));
  });
}

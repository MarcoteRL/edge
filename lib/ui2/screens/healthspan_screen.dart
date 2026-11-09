// Estimated physiological age — FORK SCREEN (MarcoteRL/edge). The model and
// every number behind it are in lib/compute/healthspan.dart.
//
// Read-only, computed on open from values already stored: the latest GPS
// VO2max estimates, the sleep regularity index and the last two weeks of
// nightly sleep. Nothing is persisted and nothing feeds another metric.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../compute/healthspan.dart';
import '../../compute/profile.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart';
import '../../state/app_state.dart';
import '../ui2.dart';
import 'home_screen.dart' show envValue;
import 'metric_detail.dart' show detailScaffold;

/// How far back a GPS VO2max estimate still counts as current fitness.
const Duration kHealthspanVo2Window = Duration(days: 180);

typedef HealthspanInputs = ({
  int? age,
  String? sex,
  double? vo2max,
  double? sri,
  List<double> sleepMin,
});

/// The median of the newest (up to) three VO2max estimates in [sessions],
/// which come newest first. One run on a hot day should not set the number.
double? latestVo2max(List<Map<String, dynamic>> sessions) {
  final xs = <double>[
    for (final s in sessions)
      if ((s['vo2max_estimate'] as num?)?.toDouble() case final v?)
        if (v.isFinite && v > 0) v,
  ].take(3).toList()
    ..sort();
  return xs.isEmpty ? null : xs[xs.length ~/ 2];
}

Future<HealthspanInputs> loadHealthspanInputs(AppState app) async {
  final profile = Profile.fromMap(app.user ?? const <String, dynamic>{});
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  double? vo2max;
  try {
    vo2max = latestVo2max(await LocalDb.sessionsInRange(
        nowSec - kHealthspanVo2Window.inSeconds, nowSec));
  } catch (_) {}
  double? sri;
  try {
    final insights = await app.repo?.getInsights() ?? const {};
    sri = (envValue(insights['regularity'])?['sri'] as num?)?.toDouble();
  } catch (_) {}
  var sleepMin = const <double>[];
  try {
    sleepMin = await LocalDb.trailingSeriesValues('tst_min', 14);
  } catch (_) {}
  return (
    age: profile.ageYears,
    sex: profile.sex,
    vo2max: vo2max,
    sri: sri,
    sleepMin: sleepMin,
  );
}

class HealthspanScreen extends StatefulWidget {
  const HealthspanScreen({super.key, this.inputs});

  /// Handed in by tests; null loads from the app.
  final HealthspanInputs? inputs;

  @override
  State<HealthspanScreen> createState() => _HealthspanScreenState();
}

class _HealthspanScreenState extends State<HealthspanScreen> {
  late final Future<HealthspanInputs> _inputs = widget.inputs != null
      ? Future.value(widget.inputs)
      : loadHealthspanInputs(context.read<AppState>());

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final title = l?.healthspanTitle ?? 'Physiological age';
    return FutureBuilder<HealthspanInputs>(
      future: _inputs,
      builder: (c, snap) {
        final d = snap.data;
        if (d == null) {
          return detailScaffold(c, title, [
            const Center(child: CircularProgressIndicator()),
          ]);
        }
        final gaps = <HealthspanGap>[];
        final est = estimateHealthspan(
          age: d.age,
          sex: d.sex,
          vo2max: d.vo2max,
          sri: d.sri,
          nightlySleepMin: d.sleepMin,
          gaps: gaps,
        );
        return detailScaffold(c, title, [
          if (est == null)
            StatusCard(
              l?.healthspanNotYetTitle ?? 'Not enough to estimate yet',
              l?.healthspanNotYetBody ??
                  'It needs your age and sex in your profile and at least two '
                      'of the three inputs below.',
              icon: LucideIcons.hourglass,
            )
          else
            _Headline(est),
          const SizedBox(height: S.x4),
          Section(
            l?.healthspanInputsTitle ?? 'What moves it',
            Column(children: [
              for (final kind in HealthspanPillarKind.values)
                _PillarRow(kind,
                    est?.pillars.where((p) => p.kind == kind).firstOrNull,
                    d),
            ]),
          ),
          const SizedBox(height: S.x4),
          Text(
            l?.healthspanMethod ??
                'Each input is compared with a published population reference '
                    'and turned into years through the mortality research behind '
                    'it: fitness against the FRIEND registry (Kaminsky 2015, '
                    'Kodama 2009), sleep regularity against UK Biobank (Windred '
                    '2024), sleep length against Cappuccio 2010. Risk doubles '
                    'about every eight years of age, which is how a risk becomes '
                    'years. Resting heart rate and steps are left out: neither '
                    'has a reference this band can be fairly placed against.',
            style: F.cap.copyWith(color: P.of(c).ink2, height: 1.5),
          ),
          const SizedBox(height: S.x3),
          Text(
            l?.healthspanDisclaimer ??
                'An estimate from population studies, not a medical age.',
            style: F.cap.copyWith(color: P.of(c).ink3, height: 1.5),
          ),
        ]);
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.est);
  final HealthspanEstimate est;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final years = est.years;
    final delta = displayFixed(years.abs(), 1);
    final line = years.abs() < 0.05
        ? (l?.healthspanSameAsAge ?? 'The same as your age')
        : years < 0
            ? (l?.healthspanYounger(delta) ?? '$delta years younger than your age')
            : (l?.healthspanOlder(delta) ?? '$delta years older than your age');
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.healthspanEstimateLabel ?? 'ESTIMATED',
            style: F.over.copyWith(color: p.ink3)),
        const SizedBox(height: S.x1),
        Text(displayFixed(est.physiologicalAge, 1),
            style: F.display.copyWith(color: p.ink)),
        Text(line,
            style: F.body.copyWith(
                color: years <= 0 ? p.on(C.green) : p.on(C.orange))),
        const SizedBox(height: S.x1),
        Text(l?.healthspanYourAge(est.age) ?? 'Your age: ${est.age}',
            style: F.cap.copyWith(color: p.ink3)),
      ]),
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow(this.kind, this.pillar, this.d);
  final HealthspanPillarKind kind;
  final HealthspanPillar? pillar;
  final HealthspanInputs d;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final (icon, name) = switch (kind) {
      HealthspanPillarKind.fitness =>
        (LucideIcons.activity, l?.healthspanFitness ?? 'Fitness (VO2max)'),
      HealthspanPillarKind.sleepRegularity => (
          LucideIcons.calendarClock,
          l?.healthspanRegularity ?? 'Sleep regularity'
        ),
      HealthspanPillarKind.sleepDuration =>
        (LucideIcons.moon, l?.healthspanDuration ?? 'Sleep length'),
    };
    final pl = pillar;
    final String detail;
    final String effect;
    if (pl == null) {
      effect = '—';
      detail = switch (kind) {
        HealthspanPillarKind.fitness => l?.healthspanFitnessMissing ??
            'Record a run or brisk walk with GPS to estimate it.',
        HealthspanPillarKind.sleepRegularity =>
          l?.healthspanRegularityMissing ??
              'Needs a week or more of nights with the band.',
        HealthspanPillarKind.sleepDuration => l?.healthspanDurationMissing ??
            'Needs at least 7 recorded nights.',
      };
    } else {
      final yrs = displayFixed(pl.years.abs(), 1);
      effect = pl.years.abs() < 0.05
          ? (l?.healthspanNoEffect ?? '±0 years')
          : pl.years < 0
              ? (l?.healthspanMinusYears(yrs) ?? '−$yrs years')
              : (l?.healthspanPlusYears(yrs) ?? '+$yrs years');
      detail = switch (kind) {
        HealthspanPillarKind.fitness => l?.healthspanFitnessDetail(
                displayFixed(pl.value, 1), displayFixed(pl.reference, 1)) ??
            '${displayFixed(pl.value, 1)} mL/kg/min against '
                '${displayFixed(pl.reference, 1)} typical for your age',
        HealthspanPillarKind.sleepRegularity => l?.healthspanRegularityDetail(
                pl.value.round(), pl.reference.round()) ??
            'Index ${pl.value.round()} against ${pl.reference.round()} typical',
        HealthspanPillarKind.sleepDuration =>
          l?.healthspanDurationDetail(displayFixed(pl.value, 1)) ??
              '${displayFixed(pl.value, 1)} h a night on average',
      };
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.x2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: pl == null ? p.ink3 : p.ink2),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: F.body.copyWith(color: p.ink)),
            Text(detail, style: F.cap.copyWith(color: p.ink3, height: 1.4)),
          ]),
        ),
        const SizedBox(width: S.x2),
        Text(effect,
            style: F.body.copyWith(
                color: pl == null
                    ? p.ink3
                    : pl.years <= 0
                        ? p.on(C.green)
                        : p.on(C.orange))),
      ]),
    );
  }
}

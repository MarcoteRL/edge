// Estimated physiological age and pace of ageing — FORK SCREEN (MarcoteRL/edge).
// The model and every number behind it: lib/compute/healthspan.dart. The data
// it reads: lib/data/healthspan_inputs.dart. Read-only, computed on open.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../compute/healthspan.dart';
import '../../data/healthspan_inputs.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart';
import '../../state/app_state.dart';
import '../ui2.dart';
import 'metric_detail.dart' show detailScaffold;

/// Today's window and the one a month earlier, for the pace.
typedef HealthspanWindows = ({HealthspanData now, HealthspanData? before});

Future<HealthspanWindows> loadHealthspanWindows(AppState app) async {
  final now = await loadHealthspanData(user: app.user, repo: app.repo);
  HealthspanData? before;
  try {
    before = await loadHealthspanData(
        user: app.user,
        end: DateTime.now().subtract(kHealthspanPaceLookback),
        sri: now.sri);
  } catch (_) {}
  return (now: now, before: before);
}

class HealthspanScreen extends StatefulWidget {
  const HealthspanScreen({super.key, this.windows});

  /// Handed in by tests; null loads from the app.
  final HealthspanWindows? windows;

  @override
  State<HealthspanScreen> createState() => _HealthspanScreenState();
}

class _HealthspanScreenState extends State<HealthspanScreen> {
  late final Future<HealthspanWindows> _data = widget.windows != null
      ? Future.value(widget.windows)
      : loadHealthspanWindows(context.read<AppState>());

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final title = l?.healthspanTitle ?? 'Physiological age';
    return FutureBuilder<HealthspanWindows>(
      future: _data,
      builder: (c, snap) {
        final w = snap.data;
        if (w == null) {
          return detailScaffold(
              c, title, [const Center(child: CircularProgressIndicator())]);
        }
        final missing = <HealthspanKind>[];
        final est = estimateHealthspan(w.now, missing: missing);
        final before = w.before == null ? null : estimateHealthspan(w.before!);
        final pace = paceOfAging(est, before,
            days: kHealthspanPaceLookback.inDays);
        return detailScaffold(c, title, [
          if (est == null)
            StatusCard(
              l?.healthspanNotYetTitle ?? 'Not enough to estimate yet',
              l?.healthspanNotYetBody ??
                  'It needs your age and sex in your profile and at least '
                      'three of the contributors below.',
              icon: LucideIcons.hourglass,
            )
          else
            _Headline(est, pace),
          const SizedBox(height: S.x4),
          Section(
            l?.healthspanInputsTitle ?? 'What moves it',
            Column(children: [
              for (final kind in HealthspanKind.values)
                _Row(kind, est?.pillars.where((x) => x.kind == kind).firstOrNull),
            ]),
          ),
          const SizedBox(height: S.x4),
          Text(
            l?.healthspanMethod ??
                'Built like WHOOP\'s Healthspan: the same nine contributors over '
                    'six months, each with a break-even at the public-health '
                    'guideline, so meeting it adds no years. WHOOP does not '
                    'publish its formulas, so each curve here comes from a '
                    'published study (Windred 2024, Cappuccio 2010, Lee 2022, '
                    'Momma 2022, Banach 2023, Kaminsky 2015 and Kodama 2009, '
                    'Zhang 2016). Risk doubles about every eight years of age, '
                    'which is how a risk becomes years.',
            style: F.cap.copyWith(color: p.ink2, height: 1.5),
          ),
          const SizedBox(height: S.x3),
          Text(
            l?.healthspanDisclaimer ??
                'An estimate from population studies, not a medical age.',
            style: F.cap.copyWith(color: p.ink3, height: 1.5),
          ),
        ]);
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.est, this.pace);
  final HealthspanEstimate est;
  final double? pace;

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
    final pc = pace;
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
        const SizedBox(height: S.x3),
        Text(
          pc == null
              ? (l?.healthspanPaceNotYet ??
                  'Pace of ageing: needs a month more of data')
              : (l?.healthspanPace(displayFixed(pc, 1)) ??
                  'Pace of ageing: ${displayFixed(pc, 1)}x'),
          style: F.body.copyWith(color: p.ink),
        ),
        Text(
          l?.healthspanPaceHelp ??
              '1x ages with the calendar, 0x holds steady, below 0 is getting '
                  'younger. From the last month against the month before.',
          style: F.cap.copyWith(color: p.ink3, height: 1.4),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.kind, this.pillar);
  final HealthspanKind kind;
  final HealthspanPillar? pillar;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final (IconData icon, String name) = switch (kind) {
      HealthspanKind.sleepConsistency => (
          LucideIcons.calendarClock,
          l?.healthspanRegularity ?? 'Sleep consistency'
        ),
      HealthspanKind.sleepHours =>
        (LucideIcons.moon, l?.healthspanDuration ?? 'Hours of sleep'),
      HealthspanKind.zones13 =>
        (LucideIcons.heart, l?.healthspanZones13 ?? 'Time in zones 1–3'),
      HealthspanKind.zones45 =>
        (LucideIcons.heartPulse, l?.healthspanZones45 ?? 'Time in zones 4–5'),
      HealthspanKind.strength =>
        (LucideIcons.dumbbell, l?.healthspanStrength ?? 'Strength activity'),
      HealthspanKind.steps =>
        (LucideIcons.footprints, l?.healthspanSteps ?? 'Steps'),
      HealthspanKind.vo2max =>
        (LucideIcons.activity, l?.healthspanFitness ?? 'VO2max'),
      HealthspanKind.restingHr =>
        (LucideIcons.heart, l?.healthspanRhr ?? 'Resting heart rate'),
      HealthspanKind.leanMass =>
        (LucideIcons.scale, l?.healthspanLeanMass ?? 'Lean body mass'),
    };
    final x = pillar;
    String f1(double v) => displayFixed(v, 1);
    String f0(double v) => displayFixed(v, 0);
    final String detail;
    if (x == null) {
      detail = switch (kind) {
        HealthspanKind.leanMass => l?.healthspanLeanMassMissing ??
            'Needs a body-composition scale.',
        HealthspanKind.vo2max => l?.healthspanFitnessMissing ??
            'Needs your weight and height, and two weeks of wear.',
        HealthspanKind.sleepConsistency ||
        HealthspanKind.sleepHours ||
        HealthspanKind.restingHr =>
          l?.healthspanNightsMissing ?? 'Needs at least 7 nights with the band.',
        _ => l?.healthspanDaysMissing ?? 'Needs two weeks with the band.',
      };
    } else {
      detail = switch (kind) {
        HealthspanKind.sleepConsistency => l?.healthspanRegularityDetail(
                x.value.round(), x.breakEven.round()) ??
            'Index ${x.value.round()} · break-even ${x.breakEven.round()}',
        HealthspanKind.sleepHours => l?.healthspanDurationDetail(f1(x.value)) ??
            '${f1(x.value)} h a night · neutral between 6 and 9 h',
        HealthspanKind.zones13 ||
        HealthspanKind.zones45 ||
        HealthspanKind.strength =>
          l?.healthspanMinutesDetail(f0(x.value), f0(x.breakEven)) ??
              '${f0(x.value)} min a week · break-even ${f0(x.breakEven)}',
        HealthspanKind.steps => l?.healthspanStepsDetail(f0(x.value)) ??
            '${f0(x.value)} a day · break-even 8,000',
        HealthspanKind.vo2max => x.estimated
            ? (l?.healthspanFitnessEstimated(f1(x.value), f1(x.breakEven)) ??
                '${f1(x.value)} mL/kg/min, estimated without exercise · '
                    'break-even ${f1(x.breakEven)}')
            : (l?.healthspanFitnessDetail(f1(x.value), f1(x.breakEven)) ??
                '${f1(x.value)} mL/kg/min from your GPS runs · break-even '
                    '${f1(x.breakEven)}'),
        HealthspanKind.restingHr => l?.healthspanRhrDetail(f0(x.value)) ??
            '${f0(x.value)} bpm at night · break-even 60 (a night reading runs '
                'low, so this leans young)',
        HealthspanKind.leanMass => '',
      };
    }
    final String effect;
    if (x == null) {
      effect = '—';
    } else {
      final yrs = displayFixed(x.years.abs(), 1);
      effect = x.years.abs() < 0.05
          ? (l?.healthspanNoEffect ?? '±0 years')
          : x.years < 0
              ? (l?.healthspanMinusYears(yrs) ?? '−$yrs years')
              : (l?.healthspanPlusYears(yrs) ?? '+$yrs years');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.x2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: x == null ? p.ink3 : p.ink2),
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
                color: x == null
                    ? p.ink3
                    : x.years <= 0
                        ? p.on(C.green)
                        : p.on(C.orange))),
      ]),
    );
  }
}

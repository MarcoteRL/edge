// FORK — iteration 5: two read-only screens over the stored series.
//
//   * PeriodLabScreen   — N days before a date against the N from it on, for
//                         one metric (compute/fork/trends.dart, ALG-P1).
//   * WeeklyReportScreen — the last 7 days in a dozen lines, and a button
//                         that hands them to the system share sheet as a
//                         Markdown file.
//
// Both follow D-15: nothing here is stored, nothing is on `getToday`'s path,
// the bootstrap runs in `Isolate.run` behind TrendService, and the work
// starts when the screen opens. Neither asks a model anything, and neither
// touches the network: the report leaves the phone only through the share
// sheet, on the user's own tap.
//
// Honesty rules, same as the rest of the fork: a period with too few days
// says how many it has and needs; "no difference beyond the noise" is never
// said when the comparison could not be made; and the lab says what differs,
// never why.

import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../compute/fork/trend_service.dart';
import '../../compute/fork/trends.dart' as fork;
import '../../data/day_label.dart';
import '../../data/strength_summary.dart';
import '../../l10n/app_localizations.dart';
import '../activity/share.dart' show shareOrigin;
import '../ui2.dart';
import 'home_guidance.dart';
import 'home_screen.dart' show hm, prettyDay, thousands;
import 'metric_detail.dart' show detailLinkRow, detailScaffold;

/// The local day [days] calendar days from [label] (negative = earlier).
/// Calendar arithmetic, so a 23 h or 25 h day is still one step.
String shiftDay(String label, int days) {
  final d = DateTime.parse(label);
  return dayLabelOf(DateTime(d.year, d.month, d.day + days));
}

String _tooFew(fork.WindowMean w, AppLocalizations? l) =>
    l?.labTooFew(w.have, w.need) ??
    '${w.have} days with data, ${w.need} needed';

// ── the period lab ─────────────────────────────────────────────────────────

/// What the lab says about one comparison. Pure, so the three outcomes are
/// testable without a database.
String periodVerdict(GuideMetric m, fork.PeriodChange r, AppLocalizations? l) {
  final d = r.delta;
  return switch (r.relevant) {
    true => l?.labChanged(m.delta(d!, l)) ??
        '${m.delta(d!, l)}: a difference beyond the night-to-night noise',
    false => l?.labSame(m.delta(d!, l)) ??
        'No difference beyond the noise (${m.delta(d!, l)})',
    null => r.note == fork.kTrendNoDispersion
        ? (l?.labFlat ??
            'Both periods are flat: there is no noise to measure a '
                'difference against')
        : (l?.labNeedDays ?? 'Not enough days in one of the periods'),
  };
}

class PeriodLabScreen extends StatefulWidget {
  const PeriodLabScreen({super.key});

  @override
  State<PeriodLabScreen> createState() => _PeriodLabScreenState();
}

class _PeriodLabScreenState extends State<PeriodLabScreen> {
  static const _lengths = [7, 14, 28];

  int _metric = 0, _len = 1;

  /// First day of the second period. Null = the default for the length: the
  /// last N days (today included) against the N before them.
  String? _split;

  fork.PeriodChange? _result;
  bool _failed = false;

  /// The question on screen; an answer to an older one is dropped.
  int _asked = 0;

  int get _days => _lengths[_len];
  String get _splitDay => _split ?? shiftDay(todayLabel(), -(_days - 1));

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _ask(VoidCallback change) {
    setState(() {
      change();
      _result = null;
      _failed = false;
    });
    _run();
  }

  Future<void> _run() async {
    final asked = ++_asked;
    try {
      final r = await TrendService.periods(
        GuideMetric.values[_metric].seriesKey,
        split: _splitDay,
        days: _days,
      );
      if (mounted && asked == _asked) setState(() => _result = r);
    } catch (_) {
      if (mounted && asked == _asked) setState(() => _failed = true);
    }
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_splitDay),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: AppLocalizations.of(context)?.labPickHelp ??
          'First day of the second period',
    );
    if (picked == null || !mounted) return;
    _ask(() => _split = dayLabelOf(picked));
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final m = GuideMetric.values[_metric];
    final split = _splitDay;
    final r = _result;
    String span(String from, String to) =>
        '${prettyDay(from, l)} – ${prettyDay(to, l)}';

    Widget period(String name, String range, fork.WindowMean w) => Padding(
          padding: const EdgeInsets.only(bottom: S.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), style: F.over.copyWith(color: p.ink3)),
              const SizedBox(height: S.x1),
              Text(range, style: F.cap.copyWith(color: p.ink2)),
              const SizedBox(height: S.x1),
              Text(
                w.mean == null ? _tooFew(w, l) : m.level(w.mean!, l),
                style: w.mean == null
                    ? F.body.copyWith(color: p.ink3)
                    : F.head.copyWith(color: p.ink),
              ),
              if (w.mean != null)
                Text(
                  l?.labDaysWith(w.have, w.days) ??
                      '${w.have} of ${w.days} days with data',
                  style: F.cap.copyWith(color: p.ink3),
                ),
            ],
          ),
        );

    return detailScaffold(
      c,
      l?.labTitle ?? 'Compare two periods',
      [
        Text(
          l?.labIntro ??
              'Pick a date. The days before it are compared with the same '
                  'number of days from it on.',
          style: F.body.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x4),
        SubTabs(
          [for (final g in GuideMetric.values) g.label(l)],
          _metric,
          (i) => _ask(() => _metric = i),
          color: C.domHealth,
        ),
        const SizedBox(height: S.x3),
        SubTabs(
          [
            for (final n in _lengths) l?.labDaysChip(n) ?? '$n days',
          ],
          _len,
          // A length change keeps a date the user picked; the default date
          // follows the length.
          (i) => _ask(() => _len = i),
          color: C.domHealth,
        ),
        const SizedBox(height: S.x3),
        detailLinkRow(
          c,
          LucideIcons.calendar,
          l?.labSplitTitle ?? 'Second period starts',
          prettyDay(split, l),
          _pick,
        ),
        const SizedBox(height: S.x4),
        if (_failed)
          StatusCard(
            l?.labFailedTitle ?? 'The comparison could not be read',
            l?.labFailedBody ?? 'Close this screen and open it again.',
            icon: LucideIcons.triangleAlert,
          )
        else if (r == null)
          const Padding(
            padding: EdgeInsets.all(S.x5),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                period(
                  l?.labBefore ?? 'Before',
                  span(shiftDay(split, -_days), shiftDay(split, -1)),
                  r.before,
                ),
                period(
                  l?.labAfter ?? 'After',
                  span(split, shiftDay(split, _days - 1)),
                  r.after,
                ),
                Text(
                  periodVerdict(m, r, l),
                  style: F.body.copyWith(
                    color: r.relevant == null ? p.ink3 : p.ink,
                    fontWeight:
                        r.relevant == true ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: S.x4),
        Text(
          l?.labCaveat ??
              'This compares two stretches of your own data. It can show '
                  'that they differ, not why, and it is not a medical '
                  'reading.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ],
    );
  }
}

// ── the weekly report ──────────────────────────────────────────────────────

typedef ReportRow = ({String label, String value});

/// The report's lines, from values already computed. Pure: every absence is
/// decided here and nowhere else — a metric with too few nights says so, a
/// week with nothing lifted has no lifting line, an unrated week's session
/// load is "at least".
List<ReportRow> weeklyReportRows({
  required List<fork.Trend> trends,
  StrengthSummary? strength,
  double? bedtimeSpreadMin,
  AppLocalizations? l,
}) {
  final rows = <ReportRow>[];
  for (final (i, m) in GuideMetric.values.indexed) {
    final week = trends[i].means.first;
    rows.add((
      label: m.label(l),
      value: week.mean == null
          ? _tooFew(week, l)
          : '${m.level(week.mean!, l)} · ${weekVerdict(m, trends[i], l)}',
    ));
  }
  if (bedtimeSpreadMin != null) {
    rows.add((
      label: l?.reportBedtimeSpread ?? 'Bedtime, night to night',
      value: '± ${hm(bedtimeSpreadMin)}',
    ));
  }
  final load = strength?.weekLoad;
  if (load != null && load.setsWithLoad > 0) {
    rows.add((
      label: l?.reportLifted ?? 'Lifted',
      value: '${thousands(load.kg.round())} kg',
    ));
  }
  final rpe = strength?.weekRpe;
  if (rpe?.total case final au?) {
    final n = thousands(au.round());
    rows.add((
      label: l?.reportSessionLoad ?? 'Session load (effort × minutes)',
      value: rpe!.complete ? n : (l?.reportAtLeast(n) ?? 'at least $n'),
    ));
  }
  return rows;
}

/// The report as a Markdown file's text.
String weeklyReportText({
  required String title,
  required String period,
  required List<ReportRow> rows,
  required String footer,
}) =>
    [
      '# $title',
      '',
      period,
      '',
      for (final r in rows) '- ${r.label}: ${r.value}',
      '',
      footer,
      '',
    ].join('\n');

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  List<fork.Trend>? _trends;
  StrengthSummary? _strength;
  double? _bedtimeSpread;
  bool _failed = false;
  bool _sharing = false;

  /// The report is of the day it was opened on, even across midnight.
  final String _today = todayLabel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trends = <fork.Trend>[
        for (final m in GuideMetric.values) await TrendService.of(m.seriesKey),
      ];
      // `sleep_onset_sec` is signed seconds either side of 04:00 local; the
      // circular spread does not care where the origin sits.
      final onsets = await TrendService.lastDays('sleep_onset_sec', 7);
      final strength = await loadStrengthSummary();
      if (!mounted) return;
      setState(() {
        _trends = trends;
        _strength = strength;
        _bedtimeSpread =
            fork.scheduleSdMin([for (final s in onsets) s / 60]);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _period(AppLocalizations? l) =>
      '${prettyDay(shiftDay(_today, -6), l)} – ${prettyDay(_today, l)}';

  Future<void> _share(List<ReportRow> rows) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    // Both read the tree, so both are read before the first await.
    final l = AppLocalizations.of(context);
    final origin = shareOrigin(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = weeklyReportText(
        title: l?.reportTitle ?? 'Weekly report',
        period: _period(l),
        rows: rows,
        footer: l?.reportFooter ??
            'Computed on your phone from your own data. A description of '
                'the week, not medical advice.',
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(text),
            mimeType: 'text/markdown',
            name: 'weekly-report-$_today.md',
          ),
        ],
        sharePositionOrigin: origin,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l?.reportShareFailed ?? 'The report could not be shared'),
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final trends = _trends;
    final rows = trends == null
        ? const <ReportRow>[]
        : weeklyReportRows(
            trends: trends,
            strength: _strength,
            bedtimeSpreadMin: _bedtimeSpread,
            l: l,
          );
    return detailScaffold(
      c,
      l?.reportTitle ?? 'Weekly report',
      sub: _period(l),
      [
        if (_failed)
          StatusCard(
            l?.reportFailedTitle ?? 'The report could not be read',
            l?.labFailedBody ?? 'Close this screen and open it again.',
            icon: LucideIcons.triangleAlert,
          )
        else if (trends == null)
          const Padding(
            padding: EdgeInsets.all(S.x5),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l?.homeEvolutionSub ??
                      'Last 7 days against the 4 weeks before',
                  style: F.cap.copyWith(color: p.ink3),
                ),
                for (final r in rows) ...[
                  const SizedBox(height: S.x3),
                  Text(r.label, style: F.cap.copyWith(color: p.ink3)),
                  const SizedBox(height: S.x1),
                  Text(r.value, style: F.body.copyWith(color: p.ink)),
                ],
              ],
            ),
          ),
          const SizedBox(height: S.x4),
          BigButton(
            l?.reportShare ?? 'Share as a file',
            icon: LucideIcons.share,
            color: C.domHealth,
            soft: true,
            busy: _sharing,
            onTap: () => _share(rows),
          ),
          const SizedBox(height: S.x3),
          Text(
            l?.reportFooter ??
                'Computed on your phone from your own data. A description '
                    'of the week, not medical advice.',
            style: F.cap.copyWith(color: p.ink3),
          ),
        ],
      ],
    );
  }
}

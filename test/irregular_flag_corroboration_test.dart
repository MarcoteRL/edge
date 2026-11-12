// ALG-C1 (docs/development/ALGORITHM_EVALUATION.md): the day's published
// irregular-rhythm verdict needs the sleep-window screen to agree with the
// 24/7 one. A real gen5 export flagged every daytime-only day and no day with
// a night — motion artifact, not rhythm.
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_analytics/onehz.dart';
import 'package:openstrap_edge/compute/onehz_pipeline.dart'
    show irregularRhythmFlag;

Metric<IrregularRhythm> _screen(bool flag) => Metric<IrregularRhythm>(
      value: IrregularRhythm(
        sd1: 40,
        sd2: 50,
        sd1sd2: 0.8,
        pnnPct: 35,
        nBeats: 600,
        flag: flag,
      ),
      confidence: 0.9,
      tier: Tier.estimate,
      inputs_used: const ['rr_cleaned'],
    );

const _absent = Metric<IrregularRhythm>.absent(
  tier: Tier.estimate,
  inputs_used: ['rr_cleaned'],
);

void main() {
  test('a daytime-only flag with no scored night is no verdict, not a flag',
      () {
    expect(irregularRhythmFlag(_screen(true), _absent), isNull);
  });

  test('a flag needs both screens', () {
    expect(irregularRhythmFlag(_screen(true), _screen(false)), 0.0);
    expect(irregularRhythmFlag(_screen(false), _screen(true)), 0.0);
    expect(irregularRhythmFlag(_screen(true), _screen(true)), 1.0);
  });

  test('a clean day with a clean night stays 0, and no day screen is null',
      () {
    expect(irregularRhythmFlag(_screen(false), _screen(false)), 0.0);
    expect(irregularRhythmFlag(_absent, _screen(true)), isNull);
  });
}

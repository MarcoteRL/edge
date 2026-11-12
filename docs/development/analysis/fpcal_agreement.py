#!/usr/bin/env python3
"""ALG-R1 — does the greyed calibration estimate (FP-CAL) agree with the real
Recovery once the real one exists?

Read-only. For every night that has a stored `readiness`, recompute the
estimate that Home would have shown for that night from the nights before it
(lib/compute/calibration_estimate.dart, mirrored below) and report, as
aggregates only: n, Spearman rho, mean absolute error and the share of nights
in the same colour band. Under MIN_NIGHTS it says so and reports nothing.

    python3 fpcal_agreement.py <export.db>

Limits: the estimate here always uses the full 28-night history (on the phone
it is only shown while the real score abstains, i.e. with fewer nights), so
this measures the estimator's formula against the composite, not the exact
numbers that were on screen during the first two weeks.
"""
import math
import sqlite3
import sys

MIN_NIGHTS = 10          # below this an agreement figure is noise
PRIOR = 3.0              # kCalibrationPriorNights
REF = {'ln_rmssd': (3.85, 0.50), 'rhr': (57.0, 8.0), 'resp': (14.5, 2.0)}
SIGN = {'ln_rmssd': 1, 'rhr': -1, 'resp': -1}
WEIGHT = {'ln_rmssd': 0.40, 'rhr': 0.30, 'resp': 0.20}   # analytics input weights
ZCAP = 2.0
BANDS = (26, 37, 61)     # Home's cuts


def blended(hist, ref):
    n = len(hist)
    if n == 0:
        return ref
    mean = sum(hist) / n
    var = 0.0 if n < 2 else sum((v - mean) ** 2 for v in hist) / (n - 1)
    centre = (PRIOR * ref[0] + n * mean) / (PRIOR + n)
    spread = math.sqrt((PRIOR * ref[1] ** 2 + n * var) / (PRIOR + n))
    return centre, max(spread, 1e-6)


def estimate(today, hist):
    if today.get('ln_rmssd') is None and today.get('rhr') is None:
        return None
    num = den = 0.0
    for k in REF:
        v = today.get(k)
        if v is None:
            continue
        c, s = blended(hist[k], REF[k])
        z = max(-ZCAP, min(ZCAP, SIGN[k] * (v - c) / s))
        num += z * WEIGHT[k]
        den += WEIGHT[k]
    return None if den <= 0 else 100 / (1 + math.exp(-num / den))


def band(v):
    return sum(v >= b for b in BANDS)


def ranks(xs):
    order = sorted(range(len(xs)), key=xs.__getitem__)
    r = [0.0] * len(xs)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and xs[order[j + 1]] == xs[order[i]]:
            j += 1
        for k in range(i, j + 1):
            r[order[k]] = (i + j) / 2 + 1
        i = j + 1
    return r


def spearman(a, b):
    ra, rb = ranks(a), ranks(b)
    ma, mb = sum(ra) / len(ra), sum(rb) / len(rb)
    cov = sum((x - ma) * (y - mb) for x, y in zip(ra, rb))
    va = math.sqrt(sum((x - ma) ** 2 for x in ra))
    vb = math.sqrt(sum((y - mb) ** 2 for y in rb))
    return None if va == 0 or vb == 0 else cov / (va * vb)


def main(path):
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    series = {}
    for key in ('readiness', 'rmssd', 'rhr', 'resp_rate'):
        series[key] = dict(db.execute(
            'SELECT date, value FROM metric_series WHERE key = ? AND value IS NOT NULL', (key,)))
    days = sorted(set(series['rmssd']) | set(series['rhr']))
    pairs = []
    for i, day in enumerate(days):
        real = series['readiness'].get(day)
        if real is None:
            continue
        before = days[max(0, i - 28):i]
        hist = {
            'ln_rmssd': [math.log(series['rmssd'][d]) for d in before
                         if series['rmssd'].get(d, 0) > 0],
            'rhr': [series['rhr'][d] for d in before if d in series['rhr']],
            'resp': [series['resp_rate'][d] for d in before if d in series['resp_rate']],
        }
        rm = series['rmssd'].get(day)
        est = estimate({'ln_rmssd': math.log(rm) if rm and rm > 0 else None,
                        'rhr': series['rhr'].get(day),
                        'resp': series['resp_rate'].get(day)}, hist)
        if est is not None:
            pairs.append((est, real))
    print(f'nights with HRV or RHR: {len(days)}; with a real readiness and an estimate: {len(pairs)}')
    if len(pairs) < MIN_NIGHTS:
        print(f'not enough data: need {MIN_NIGHTS} such nights, have {len(pairs)}. Nothing to report.')
        return
    est, real = zip(*pairs)
    rho = spearman(list(est), list(real))
    mae = sum(abs(a - b) for a, b in pairs) / len(pairs)
    same = sum(band(a) == band(b) for a, b in pairs) / len(pairs)
    print(f'Spearman rho: {rho:.2f}' if rho is not None else 'Spearman rho: undefined (no variance)')
    print(f'mean absolute error: {mae:.1f} points')
    print(f'same colour band: {100 * same:.0f} %')


if __name__ == '__main__':
    main(sys.argv[1])

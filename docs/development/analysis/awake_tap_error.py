#!/usr/bin/env python3
"""ALG-S1 — how far is the band's own "asleep" envelope from a real wake-up?

Read-only, aggregates only. A night closed with "I'm awake" is recognised by
the rule pinned in test/awake_tap_provenance_test.dart (ALGORITHMS.md §4):

    source = 'manual' AND abs(created_at - offset_ts) <= 60

For those nights this reports how long after the tap the band's
`band_sleep_state` kept saying "asleep" (2), while the seconds are still in
the live table.

    python3 awake_tap_error.py <export.db>

WHAT IT CANNOT DO YET: the error of the app's AUTOMATIC end. Once a night has
an override the stored candidate holds the overridden window, so where the
automatic window would have ended is not in the export. That needs the night
re-derived without its override on a copy (a follow-up; DATA-02 makes it
possible for archived nights too).
"""
import sqlite3
import statistics
import sys

MIN_NIGHTS = 10
RULE = "source = 'manual' AND abs(created_at - offset_ts) <= 60"


def main(path):
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    total = db.execute("SELECT COUNT(*) FROM sleep_override WHERE source = 'manual'").fetchone()[0]
    taps = db.execute(f'SELECT day_id, offset_ts FROM sleep_override WHERE {RULE}').fetchall()
    print(f"manual windows: {total}; recognised as an I'm-awake tap: {len(taps)}")
    late = []
    for _, off in taps:
        rows = db.execute(
            'SELECT rec_ts, band_sleep_state FROM decoded_onehz '
            "WHERE device_id = '' AND rec_ts >= ? AND rec_ts < ? ORDER BY rec_ts",
            (off, off + 4 * 3600)).fetchall()
        if not rows:
            continue  # pruned: only the archive has it
        last = off
        for ts, state in rows:
            if state != 2:
                break
            last = ts
        late.append((last - off) / 60)
    print(f'taps whose following hours are still live: {len(late)}')
    if len(late) < MIN_NIGHTS:
        print(f'not enough data: need {MIN_NIGHTS}, have {len(late)}. Nothing to report.')
        return
    print(f'band keeps saying asleep after the tap: median {statistics.median(late):.0f} min, '
          f'p90 {sorted(late)[int(0.9 * (len(late) - 1))]:.0f} min')


if __name__ == '__main__':
    main(sys.argv[1])

#!/usr/bin/env python3
"""Regenerate test/fixtures/day_payload_contract.json (T-02).

The contract is the SHAPE of `day_result.payload_json` that the read seam
(lib/data/local_repository_impl.dart) depends on: for every payload path
whose keys the read seam names as string literals, the JSON types seen in the
WHOOP freeze goldens (test/fixtures/whoop_freeze/*.json), `null` and
`absent` included.

Run from the repo root after a deliberate kAlgoVersion bump has regenerated
the goldens:  python3 tool/payload_contract.py
Review the diff: it is the list of shape changes the read seam must survive.
test/payload_contract_test.dart fails until this file matches the goldens and
the current kAlgoVersion.
"""
import glob, json, re, sys

MAX_DEPTH = 4  # deeper blocks are series / per-item detail, not seam keys


def jtype(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'bool'
    if isinstance(v, (int, float)): return 'number'
    if isinstance(v, str): return 'string'
    if isinstance(v, list): return 'list'
    return 'map'


def walk(v, path, out, depth):
    out.setdefault(path, set()).add(jtype(v))
    if isinstance(v, dict) and depth < MAX_DEPTH:
        for k, c in v.items():
            walk(c, f'{path}.{k}' if path else k, out, depth + 1)


def main():
    seam = open('lib/data/local_repository_impl.dart', encoding='utf-8').read()
    literals = set(re.findall(r"'([a-z][a-z0-9_]*)'", seam))
    version = int(re.search(r'const int kAlgoVersion = (\d+);',
        open('lib/compute/derivation_engine.dart', encoding='utf-8').read()).group(1))
    days = []
    for f in sorted(glob.glob('test/fixtures/whoop_freeze/*.json')):
        for row in json.load(open(f, encoding='utf-8'))['day_result']:
            if row['algo_version'] != version:
                sys.exit(f'{f}: golden is v{row["algo_version"]}, code is v{version}')
            days.append(row['payload_json'])
    per_day = []
    for d in days:
        out = {}
        for k, c in d.items():
            walk(c, k, out, 1)
        per_day.append(out)
    paths = {}
    for p in sorted(set().union(*per_day)):
        if not all(k in literals for k in p.split('.')):
            continue
        types = set()
        for out in per_day:
            types |= out.get(p, {'absent'})
        paths[p] = sorted(types)
    json.dump({'algo_version': version, 'max_depth': MAX_DEPTH, 'paths': paths},
              open('test/fixtures/day_payload_contract.json', 'w', encoding='utf-8'),
              indent=1, sort_keys=True)
    print(f'{len(paths)} paths, v{version}, {len(days)} golden days')


if __name__ == '__main__':
    main()

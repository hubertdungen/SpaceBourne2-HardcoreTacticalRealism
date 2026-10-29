"""Print rows of CurveTable/CurveFloat dumps as compact key lists. usage: curves.py <json>..."""
import json, sys

def keys_of(v):
    ks = v.get('Keys') or v.get('FloatCurve', {}).get('Keys') or []
    return [(round(k.get('Time', 0), 2), round(k.get('Value', 0), 3)) for k in ks]

for p in sys.argv[1:]:
    data = json.load(open(p, encoding='utf-8'))
    print('#####', p.split('\\')[-1])
    for ex in data:
        for c in (ex.get('Properties', {}) or {}).get('CurveData', []) or []:
            ks = [(round(k['Time'], 1), round(k['Value'], 2), k.get('InterpMode', '')[5:]) for k in c.get('Curve', {}).get('Keys', [])]
            print(f"  {c.get('Name')}: {ks}")
        rows = ex.get('Rows')
        if isinstance(rows, dict):
            for name, v in rows.items():
                ks = keys_of(v) if isinstance(v, dict) else []
                if ks:
                    pick = [k for k in ks if k[0] in (0, 1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 100)] or ks[:8]
                    print(f'  {name}: n={len(ks)} {pick}')
                else:
                    print(f'  {name}: {json.dumps(v)[:300]}')
        elif ex.get('Type') in ('CurveFloat',):
            print('  ', ex.get('Name'), keys_of(ex.get('Properties', {})))

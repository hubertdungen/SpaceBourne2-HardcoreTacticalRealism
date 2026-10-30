"""Hits-to-kill with the optional gear bonus (mirror of htr/ballistics.lua + htr/gear.lua).
usage: python gear_table.py [pen] [dmg] [rating] [wear] [maxlevel]"""
import math, sys

FLOOR, ABL = 0.18, 0.28
CAL = {'pistol': (52, 30), 'rifle': (55, 42), 'smg': (50, 30), 'dmr': (85, 58), 'npc_rifle': (50, 42)}
ARM = {'none': 0, 'light': 35, 'medium': 50, 'heavy': 64, 'power': 72}

PEN, DMG, RAT, WEAR, MAXL = [float(a) for a in (sys.argv[1:] + ['8', '0.15', '8', '0.25', '60'][len(sys.argv) - 1:])]


def quality(level):
    return max(0.0, min(1.0, math.log(max(1, level)) / math.log(MAXL)))


def pass_frac(pen, r):
    if r <= 0: return 1.0
    x = pen / r
    if x >= 1.5: return 1.0
    if x <= 0.5: return FLOOR
    return FLOOR + (x - 0.5) * (1 - FLOOR)


def hits(cal, armor, wl, al):
    dmg, pen = CAL[cal]
    wq, aq = quality(wl), quality(al)
    base = ARM[armor]
    hp, integ, n = 100.0, 1.0, 0
    while hp > 0 and n < 99:
        r = (base + aq * RAT) if base > 0 else 0
        r *= 0.35 + 0.65 * integ
        raw = dmg * (1 + wq * DMG)
        p = pass_frac(pen + wq * PEN, r)
        eff = max(raw * p, 10)
        hp -= eff
        if r > 0: integ = max(0, integ - raw * (1 - p) * ABL * (1 - aq * WEAR) / 100)
        n += 1
    return n


levels = [1, 10, 30, 60]
print(f"pen +{PEN:g}  dmg +{DMG*100:g}%  armor +{RAT:g}  wear -{WEAR*100:g}%  full at level {MAXL:g}")
print("quality by level:", ", ".join(f"L{l}={quality(l):.2f}" for l in [1, 5, 10, 20, 30, 45, 60]))
for cal in ['pistol', 'rifle', 'dmr']:
    for armor in ['none', 'medium', 'heavy', 'power']:
        row = []
        for wl in levels:
            row.append("/".join(str(hits(cal, armor, wl, al)) for al in levels))
        print(f"{cal:7s} vs {armor:6s}: " + "  ".join(f"W{wl}:{r}" for wl, r in zip(levels, row)))

"""Difficulty rating research (doc/research/difficulty-rating.md): measures each Standard difficulty's swing parts the
way game/scripts/MapStats.gd does (burst, cross, crossed, turn, plus reaction time and the median swing gap), compares
them with BeatLeader's stars, fits the star formula and the level cut-offs, and checks the old and new levels.
Input: the JSONL written by difficulty_fetch.py. Needs numpy.
Usage: python3 -I difficulty_fit.py <maps.jsonl>
"""
import json, math, sys
import numpy as np
SRC = sys.argv[1]
STACK = 0.05; AWK = 1.0
CUT = {0:(0,1),1:(0,-1),2:(-1,0),3:(1,0),4:(-.7071,.7071),5:(.7071,.7071),6:(-.7071,-.7071),7:(.7071,-.7071)}
RT_B = [1.04, 0.903, 0.776, 0.645]; GAP_B = [0.866, 0.646, 0.496, 0.383]
ORDER = ["Easy","Normal","Hard","Expert","ExpertPlus"]
def rt(bpm, njs, off):
    if bpm <= 0: return 0
    spb = 60/bpm; h = 4.0
    while njs*spb*h > 17.999: h /= 2
    return max(h+off, .25)*spb
def band(v, b):
    for i, x in enumerate(b):
        if v >= x: return i
    return 4
def ang(a, b):
    d = math.degrees(math.atan2(a[0]*b[1]-a[1]*b[0], a[0]*b[0]+a[1]*b[1])); return abs(d)
def swings(notes, spb):
    """per hand list of [t, vec, x, y] (first note of group sets dir, mean pos)."""
    out = [[], []]
    for hand in (0, 1):
        ns = sorted([n for n in notes if n[1] == hand], key=lambda n: n[0]); i = 0
        while i < len(ns):
            t = ns[i][0]*spb; vec = None; xs = []; ys = []; cross_far = False
            while i < len(ns) and ns[i][0]*spb - t < STACK:
                if vec is None and ns[i][4] in CUT: vec = CUT[ns[i][4]]
                xs.append(ns[i][2]); ys.append(ns[i][3]); i += 1
            out[hand].append([t, vec, xs, ys])
    return out
def features(bpm, d):
    spb = 60/bpm; notes = d["notes"]
    if len(notes) < 20: return None
    sw = swings(notes, spb)
    last = max(n[0] for n in notes)*spb; first = min(n[0] for n in notes)*spb
    dur = max(last-first, 1)
    total = sum(len(s) for s in sw)
    gaps = []; awk = 0; awk_turn = 0; far = 0; mid = 0; dist = []; speed = []
    for hand in (0, 1):
        lt = -1e9; lv = None; lx = None; ly = None
        for t, v, xs, ys in sw[hand]:
            x = sum(xs)/len(xs); y = sum(ys)/len(ys)
            if t - lt >= STACK and lt > -1e8: gaps.append(t-lt)
            if (hand == 0 and 3 in xs) or (hand == 1 and 0 in xs): awk += 1; far += 1
            if (hand == 0 and max(xs) >= 2) or (hand == 1 and min(xs) <= 1):
                mid += 1 if (hand == 0 and 3 in xs) or (hand == 1 and 0 in xs) else 0.5
            if t-lt < AWK and v and lv:
                a = ang(v, (-lv[0], -lv[1]))
                if a > 112.5: awk += 2; awk_turn += 2
                elif a > 67.5: awk += 1; awk_turn += 1
            if lx is not None and t-lt < AWK:
                dd = math.hypot(x-lx, (y-ly)*1.0); dist.append(dd); speed.append(dd/max(t-lt, .05))
            lv = v if v else ((-lv[0], -lv[1]) if lv else None); lt = t; lx = x; ly = y
    # arms crossed: a swing of one hand within 0.25 s of the other hand's last swing, left x > right x
    ev = sorted([(s[0], h, sum(s[2])/len(s[2])) for h in (0, 1) for s in sw[h]])
    lastpos = [None, None]; crossed = 0
    for t, h, x in ev:
        lastpos[h] = (t, x); o = lastpos[1-h]
        if o and t - o[0] < 0.25:
            lx_, rx_ = (x, o[1]) if h == 0 else (o[1], x)
            if lx_ > rx_: crossed += 1
    # burst: swings per second in sliding 4 s windows (both hands), 90th percentile
    ts = np.array(sorted(e[0] for e in ev)); wins = []
    for s in np.arange(ts[0], ts[-1]-4, 1.0):
        wins.append(((ts >= s) & (ts < s+4)).sum()/4)
    gaps = np.array(gaps) if gaps else np.array([0.0])
    r = rt(bpm, d["njs"], d["offset"])
    gap_med = float(np.median(gaps)) if len(gaps) > 1 else 0
    flow = 100*awk/total
    lvl = band(r, RT_B)
    if gap_med > 0: lvl = max(lvl, band(gap_med, GAP_B))
    if flow >= 10: lvl += 1
    return dict(rt=r, nps=len(notes)/dur, sps=total/dur, gap=gap_med, gap_p20=float(np.percentile(gaps, 20)),
                burst=float(sorted(wins)[int(0.9*(len(wins)-1))]) if wins else total/max(dur,4), flow=flow, turn=100*awk_turn/total,
                far=100*far/total, mid=100*mid/total, crossed=100*crossed/total,
                dist=float(np.mean(dist)) if dist else 0, speed=float(np.median(speed)) if speed else 0,
                speed_p90=float(np.percentile(speed, 90)) if speed else 0, level=min(lvl, 4))
rows = []
for line in open(SRC):
    m = json.loads(line)
    if not m["bpm"]: continue
    for name, d in m["diffs"].items():
        bl = m["bl"].get(name, {})
        if not bl or bl.get("passRating") is None: continue
        f = features(float(m["bpm"]), d)
        if f is None: continue
        f.update(id=m["id"], song=m["name"], diff=name, label=ORDER.index(name) if name in ORDER else -1,
                 stars=bl["stars"], pass_=bl["passRating"], tech=bl["techRating"], acc=bl["accRating"])
        rows.append(f)
print(len(rows), "difficulties")

# --- how well each part follows BeatLeader's stars (Spearman rank correlation) ---
def spear(a, b):
    ra = np.argsort(np.argsort(a)); rb = np.argsort(np.argsort(b)); return np.corrcoef(ra, rb)[0, 1]
y = np.array([r["stars"] for r in rows])
print("spearman with stars: current level %.2f, mapper label %.2f" % (spear(np.array([r["level"] for r in rows]), y), spear(np.array([r["label"] for r in rows]), y)))
for k in ("rt", "nps", "gap", "burst", "flow", "turn", "far", "mid", "crossed"):
    print("  %-8s %+.2f" % (k, spear(np.array([r[k] for r in rows]), y)))
# --- fit (5-fold cross-validation grouped by map) ---
rng = np.random.default_rng(1)
ids = sorted(set(r["id"] for r in rows)); rng.shuffle(ids); fold = {m: i % 5 for i, m in enumerate(ids)}
g = np.array([fold[r["id"]] for r in rows])
def fit(names, feats):
    A = np.column_stack([[f(r) for r in rows] for f in feats] + [np.ones(len(rows))]); pred = np.zeros(len(y))
    for i in range(5):
        w, *_ = np.linalg.lstsq(A[g != i], y[g != i], rcond=None); pred[g == i] = A[g == i] @ w
    w, *_ = np.linalg.lstsq(A, y, rcond=None)
    r2 = 1 - ((y - pred) ** 2).sum() / ((y - y.mean()) ** 2).sum()
    print("R2(cv) %.3f %s weights %s" % (r2, names, np.round(w, 3)))
    return w, pred, A
fit("1/rt 1/gap flow (old inputs)", [lambda r: 1 / r["rt"], lambda r: 1 / max(r["gap"], .05), lambda r: r["flow"]])
fit("+ burst", [lambda r: 1 / r["rt"], lambda r: 1 / max(r["gap"], .05), lambda r: r["flow"], lambda r: r["burst"]])
w, pred, A = fit("burst cross crossed turn (game)", [lambda r: r["burst"], lambda r: r["mid"], lambda r: r["crossed"], lambda r: r["turn"]])
print("stars per standard deviation", np.round(w[:-1] * A[:, :-1].std(0), 2))
# --- level cut-offs: midpoints between the median stars of neighbouring mapper labels ---
lab = np.array([r["label"] for r in rows]); lvl = np.array([r["level"] for r in rows])
med = [np.median(y[lab == i]) for i in range(5)]
cuts = [(med[i] + med[i + 1]) / 2 for i in range(4)]
print("median stars by label", np.round(med, 2), "cut-offs", np.round(cuts, 2))
yb = np.searchsorted(cuts, y)
for name, L in (("old level", lvl), ("new level (cv)", np.searchsorted(cuts, pred)), ("mapper label", lab)):
    print("%-15s same %.0f%% harder %.0f%% easier %.0f%%" % (name, np.mean(L == yb) * 100, np.mean(L > yb) * 100, np.mean(L < yb) * 100))

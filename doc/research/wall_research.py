"""Count body moves that walls force per difficulty: leans (a floor-to-head wall over one of the two
middle columns) and squats (a wall over the head row with room below, across both middle columns).
Usage: python3 -I wall_research.py <zip_dir_or_song_dir> [...]
"""
import json, os, sys, zipfile, statistics

GROUP_S = 0.1   # walls starting this close are one move
DIFFS = ["Easy", "Normal", "Hard", "Expert", "ExpertPlus"]


def walls_of(dj):
    """[(beat, x, w, y, h)] in v3-style rows 0..4 (v2 full wall y0 h5, crouch y2 h3)."""
    out = []
    if "_obstacles" in dj:
        for o in dj["_obstacles"]:
            if not isinstance(o, dict): continue
            t = o.get("_type", 0)
            if t == 0: y, h = 0, 5
            elif t == 1: y, h = 2, 3
            else: continue
            out.append((float(o.get("_time", 0)), o.get("_lineIndex", 0), o.get("_width", 1), y, h, float(o.get("_duration", 0))))
    elif "obstacles" in dj:
        data = dj.get("obstaclesData")
        for o in dj["obstacles"]:
            if not isinstance(o, dict): continue
            s = data[o.get("i", 0)] if data is not None and o.get("i", 0) < len(data) else o
            out.append((float(o.get("b", 0)), s.get("x", 0), s.get("w", 1), s.get("y", 0), s.get("h", 5), float(s.get("d", 0))))
    return out


def moves(walls, bpm, song_s):
    spb = 60.0 / bpm
    ev = []
    for b, x, w, y, h, d in walls:
        if w <= 0 or h <= 0 or d <= 0: continue
        c1, c2 = x <= 1 < x + w, x <= 2 < x + w
        head = y <= 2 < y + h
        if head and y >= 1 and c1 and c2: kind = "squat"
        elif y == 0 and h >= 3 and c1 != c2: kind = "lean_r" if c1 else "lean_l"
        else: continue
        ev.append((b * spb, kind))
    ev.sort()
    merged = []
    for t, k in ev:
        if merged and t - merged[-1][0] < GROUP_S and merged[-1][1] == k: continue
        merged.append((t, k))
    mins = max(song_s, 1) / 60
    leans = [k for t, k in merged if k.startswith("lean")]
    sw = sum(1 for a, b in zip(leans, leans[1:]) if a != b)
    sets = _sets(merged)
    in_set = sum(e - b for b, e, n, k in sets)
    return {"sets": len(sets), "set_reps": sum(n for _, _, n, _ in sets), "set_share": in_set / max(song_s, 1),
            "set_kinds": sorted({k for *_, k in sets}), "squat_pm": sum(k == "squat" for _, k in merged) / mins, "lean_pm": len(leans) / mins, "switch_pm": sw / mins}


MAX_REP_GAP_S = 4.0  # a move later than this after the last one ends the set
MIN_SET_REPS = 8     # ACSM-style set size (8-12 repetitions)


def _sets(events):
    """Runs of body moves that repeat steadily enough to count as an exercise set:
    [(start s, end s, reps, kind)] with kind "lean" (side to side) or "squat"."""
    out = []
    for kind in ("lean", "squat"):
        ts = [t for t, k in events if k.startswith(kind)]
        start = 0
        for i in range(1, len(ts) + 1):
            if i == len(ts) or ts[i] - ts[i - 1] > MAX_REP_GAP_S:
                if i - start >= MIN_SET_REPS:
                    out.append((ts[start], ts[i - 1], i - start, kind))
                start = i
    return out


def read_set(open_file, names):
    info = json.loads(open_file(names["info.dat"]).decode("utf-8-sig"))
    if "_beatsPerMinute" in info:
        bpm = info["_beatsPerMinute"]; title = info.get("_songName", "")
        files = {b["_difficulty"]: b["_beatmapFilename"] for s in info.get("_difficultyBeatmapSets", [])
                 if s.get("_beatmapCharacteristicName") == "Standard" for b in s["_difficultyBeatmaps"]}
    else:
        bpm = info["audio"]["bpm"]; title = info["song"]["title"]
        files = {b["difficulty"]: b["beatmapDataFilename"] for b in info.get("difficultyBeatmaps", []) if b.get("characteristic") == "Standard"}
    for diff, fn in files.items():
        if diff not in DIFFS or not fn or fn.lower() not in names: continue
        dj = json.loads(open_file(names[fn.lower()]).decode("utf-8-sig"))
        notes = dj.get("_notes") or dj.get("colorNotes") or []
        beats = [float(n.get("_time", n.get("b", 0))) for n in notes if isinstance(n, dict)]
        song_s = (max(beats) - min(beats)) * 60 / bpm if len(beats) > 1 else 0
        if song_s < 30: continue
        yield title, diff, moves(walls_of(dj), bpm, song_s)


rows = []
for root in sys.argv[1:]:
    for f in sorted(os.listdir(root)):
        p = os.path.join(root, f)
        try:
            if f.endswith(".zip"):
                z = zipfile.ZipFile(p); names = {n.lower(): n for n in z.namelist()}
                if "info.dat" in names: rows += [(r, "bs") for r in read_set(z.read, names)]
            elif os.path.isdir(p):
                names = {n.lower(): n for n in os.listdir(p)}
                if "info.dat" in names: rows += [(r, "hs") for r in read_set(lambda n: open(os.path.join(p, n), "rb").read(), names)]
        except Exception as e:
            print("skip", f, e, file=sys.stderr)
json.dump([dict(src=s, title=t, diff=d, **m) for (t, d, m), s in rows], sys.stdout)

"""Measure the body moves walls ask for (squats, side steps) per difficulty, and how much of a map
chains them into exercise-like sets (doc/research/wall-workout.md).

A wall forces a move only when it covers where the head is: the middle of the grid, between
columns 1 and 2, at standing height.
- squat: the wall's bottom is at layer 1.5 or higher and it spans both middle columns;
- side step: the wall reaches from the floor to head height (bottom <= 1, top >= 3) and covers exactly one
  middle column, so the head goes to the other side.
Walls of the same move that touch (gap < MERGE_S) are one hold, and each hold is one move.
A set is a run of at least SET_MOVES moves of one kind (squats, or steps to either side), each
within SET_GAP_S of the last (ACSM's 8-12 repetitions per set). Same rules as MapStats._workout.

Usage: python3 -I wall_research.py <dir with map zips or unpacked song folders> <out.json>
"""
import json, os, statistics, sys, zipfile

DATA, OUT = sys.argv[1], sys.argv[2]
DIFFS = ["Easy", "Normal", "Hard", "Expert", "ExpertPlus"]
MERGE_S = 0.25
SET_MOVES, SET_GAP_S = 8, 4.0


def walls_of(dj):
    """[(beat, duration_beats, x, y, w, h)] for v2/v3/v4."""
    out = []
    if "_obstacles" in dj:
        for o in dj["_obstacles"]:
            if not isinstance(o, dict):
                continue
            t = o.get("_type", 0)
            y, h = {0: (0, 5), 1: (2, 3)}.get(t, (o.get("_lineLayer", 0), o.get("_height", 0)))
            out.append((float(o.get("_time", 0)), float(o.get("_duration", 0)), o.get("_lineIndex", 0), y, o.get("_width", 0), h))
    elif "obstacles" in dj:
        data = dj.get("obstaclesData")
        for o in dj["obstacles"]:
            if not isinstance(o, dict):
                continue
            src = data[o.get("i", 0)] if data is not None and o.get("i", 0) < len(data) else o
            out.append((float(o.get("b", 0)), float(src.get("d", 0)), src.get("x", 0), src.get("y", 0), src.get("w", 0), src.get("h", 0)))
    return out


def move_of(x, y, w, h):
    left, right = x <= 1 < x + w, x <= 2 < x + w
    if y >= 1.5 and left and right:
        return "squat"
    if y <= 1 and y + h >= 3 and left != right:
        return "lean_right" if left else "lean_left"
    return None


def metrics(walls, bpm, length_s):
    spb = 60.0 / bpm
    holds = []  # [start_s, end_s, move]
    for b, d, x, y, w, h in sorted(walls):
        m = move_of(x, y, w, h)
        if not m:
            continue
        s, e = b * spb, (b + max(d, 0)) * spb
        if holds and holds[-1][2] == m and s - holds[-1][1] < MERGE_S:
            holds[-1][1] = max(holds[-1][1], e)
        else:
            holds.append([s, e, m])
    squats = sum(1 for h in holds if h[2] == "squat")
    sets, set_s, run = 0, 0.0, 0
    for i in range(len(holds) + 1):
        ends = i == len(holds) or (holds[i][2] == "squat") != (holds[run][2] == "squat") \
            or holds[i][0] - holds[i - 1][0] > SET_GAP_S
        if i > 0 and ends:
            if i - run >= SET_MOVES:
                sets += 1
                set_s += holds[i - 1][1] - holds[run][0]
            run = i
    return {"squats": squats, "side_steps": len(holds) - squats, "sets": sets,
            "set_pct": round(set_s / max(length_s, 1) * 100, 1)}


def maps(path):
    """(name, reader) for each zip or song folder."""
    for f in sorted(os.listdir(path)):
        p = os.path.join(path, f)
        if f.endswith(".zip"):
            z = zipfile.ZipFile(p)
            names = {n.lower().split("/")[-1]: n for n in z.namelist()}
            yield f[:-4], names, lambda n, z=z: z.read(n)
        elif os.path.isdir(p):
            names = {n.lower(): os.path.join(p, n) for n in os.listdir(p)}
            yield f, names, lambda n: open(n, "rb").read()


def main():
    rows = []
    for mid, names, read in maps(DATA):
        try:
            info = json.loads(read(names["info.dat"]).decode("utf-8-sig"))
            bpm = float(info.get("_beatsPerMinute") or info.get("audio", {}).get("bpm") or 0)
            if bpm <= 0:
                continue
            files = {}
            for s in info.get("_difficultyBeatmapSets", []):
                if s.get("_beatmapCharacteristicName") == "Standard":
                    for b in s.get("_difficultyBeatmaps", []):
                        files[b["_difficulty"]] = b["_beatmapFilename"]
            for b in info.get("difficultyBeatmaps", []):
                if b.get("characteristic") == "Standard":
                    files[b["difficulty"]] = b.get("beatmapDataFilename")
            for diff, fn in files.items():
                if diff not in DIFFS or not fn or fn.lower() not in names:
                    continue
                dj = json.loads(read(names[fn.lower()]).decode("utf-8-sig"))
                walls = walls_of(dj)
                beats = [b + d for b, d, *_ in walls] + [float(n.get("_time", n.get("b", 0))) for n in
                         dj.get("_notes", dj.get("colorNotes", [])) if isinstance(n, dict)]
                length_s = max(beats, default=0) * 60.0 / bpm
                rows.append({"id": mid, "diff": diff, "walls": len(walls), **metrics(walls, bpm, length_s)})
        except Exception as e:
            print("map fail", mid, e, file=sys.stderr)
    json.dump(rows, open(OUT, "w"))
    n = len(rows)
    print("difficulties", n)
    if not n:
        return
    for k in ("squats", "side_steps", "sets", "set_pct"):
        v = sorted(r[k] for r in rows)
        print(k, "median", statistics.median(v), "p75", v[int(n * 0.75)], "p90", v[int(n * 0.9)], "max", v[-1])
    print("with a set", sum(1 for r in rows if r["sets"] > 0), "of", n,
          "· 30% or more in sets", sum(1 for r in rows if r["set_pct"] >= 30), "of", n)
    for r in sorted(rows, key=lambda r: -r["set_pct"])[:10]:
        print(r)


if __name__ == "__main__":
    main()

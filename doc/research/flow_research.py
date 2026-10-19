"""Measure swing-flow metrics per difficulty from cached BeatSaver map zips and compare them with
BeatLeader tech/pass/acc ratings.

Per hand, notes closer than STACK_S are one swing (direction from the first arrow in the group).
For each swing after the first, deviation = angle between this swing's direction and the reverse
of the previous one: 0 = clean back-and-forth, 45 = small bend, 90 = right-angle turn, >=135 = the
hand must reset (swing the same way twice). Dots take the ideal reverse (deviation 0).
Usage: python3 -I flow_research.py <data_dir_with_zips> <out.json>
"""
import json, math, os, statistics, sys, time, urllib.request, zipfile

DATA, OUT = sys.argv[1], sys.argv[2]
STACK_S = 0.05
FAST_GAP_S = 1.0  # a reset or turn slower than this gives the player time to recover
DIFFS = ["Easy", "Normal", "Hard", "Expert", "ExpertPlus"]
VEC = {0: (0, 1), 1: (0, -1), 2: (-1, 0), 3: (1, 0), 4: (-1, 1), 5: (1, 1), 6: (-1, -1), 7: (1, -1)}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "BoredSaber-research/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())


def notes_of(dj):
    """[(beat, hand, x, dir)] for v2/v3/v4."""
    out = []
    if "_notes" in dj:
        for n in dj["_notes"]:
            if isinstance(n, dict) and n.get("_type") in (0, 1):
                out.append((float(n.get("_time", 0)), n["_type"], n.get("_lineIndex", 0), n.get("_cutDirection", 8), n.get("_lineLayer", 0)))
    elif "colorNotes" in dj:
        data = dj.get("colorNotesData")
        for n in dj["colorNotes"]:
            if not isinstance(n, dict):
                continue
            src = data[n.get("i", 0)] if data is not None and n.get("i", 0) < len(data) else n
            c = src.get("c", 0)
            if c in (0, 1):
                out.append((float(n.get("b", 0)), c, src.get("x", 0), src.get("d", 8), src.get("y", 0)))
    return out


def angle(a, b):
    na, nb = math.hypot(*a), math.hypot(*b)
    c = (a[0] * b[0] + a[1] * b[1]) / (na * nb)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def metrics(notes, bpm):
    spb = 60.0 / bpm
    swings = turns = resets = fast_turns = fast_resets = dots = cross = total = jumps = 0
    travel = []
    devs = []
    for hand in (0, 1):
        hn = sorted((b * spb, x, d, y) for b, h, x, d, y in notes if h == hand)
        groups = []
        for t, x, d, y in hn:
            total += 1
            if d == 8:
                dots += 1
            if (hand == 0 and x >= 3) or (hand == 1 and x <= 0):
                cross += 1
            if groups and t - groups[-1][0] < STACK_S:
                if groups[-1][1] is None and d in VEC:
                    groups[-1][1] = VEC[d]
                continue
            groups.append([t, VEC.get(d), x, y])
        prev_dir, prev_t = None, None
        prev_pos = None
        for t, v, x, y in groups:
            swings += 1
            if prev_dir is not None:
                cur = v if v is not None else (-prev_dir[0], -prev_dir[1])
                dev = angle(cur, (-prev_dir[0], -prev_dir[1]))
                devs.append(dev)
                fast = t - prev_t < FAST_GAP_S
                if dev >= 134:
                    resets += 1
                    fast_resets += fast
                elif dev >= 89:
                    turns += 1
                    fast_turns += fast
                prev_dir = cur
            else:
                prev_dir = v if v is not None else (0, -1)
            if prev_pos is not None:
                dist = math.hypot(x - prev_pos[0], y - prev_pos[1])
                travel.append(dist)
                jumps += dist >= 2 and t - prev_t < 0.5
            prev_pos = (x, y)
            prev_t = t
    if swings < 20:
        return None
    return {"swings": swings, "reset_rate": resets / swings, "fast_reset_rate": fast_resets / swings,
            "turn_rate": turns / swings, "fast_turn_rate": fast_turns / swings,
            "mean_dev": statistics.fmean(devs), "dot_rate": dots / total, "cross_rate": cross / total, "travel": statistics.fmean(travel), "jump_rate": jumps / swings,
            "nps": total / max(1e-9, (max(n[0] for n in notes) - min(n[0] for n in notes)) * spb)}


def main():
    zips = sorted(f[:-4] for f in os.listdir(DATA) if f.endswith(".zip"))
    hashes = {}
    for i in range(0, len(zips), 50):
        d = get("https://api.beatsaver.com/maps/ids/" + ",".join(zips[i:i + 50]))
        for mid, m in d.items():
            if m.get("versions"):
                hashes[mid] = (m["versions"][0]["hash"], m["metadata"].get("bpm") or 0)
        time.sleep(0.4)
    rows = []
    for mid in zips:
        if mid not in hashes:
            continue
        h, bpm = hashes[mid]
        if bpm <= 0:
            continue
        ratings = {}
        try:
            for lb in get("https://api.beatleader.xyz/leaderboards/hash/" + h).get("leaderboards", []):
                df = lb.get("difficulty", {})
                if df.get("modeName") == "Standard":
                    ratings[df.get("difficultyName")] = {k: df.get(k) for k in ("stars", "passRating", "accRating", "techRating")}
        except Exception as e:
            print("bl fail", mid, e, file=sys.stderr)
        time.sleep(0.3)
        try:
            z = zipfile.ZipFile(os.path.join(DATA, mid + ".zip"))
            names = {n.lower(): n for n in z.namelist()}
            info = json.loads(z.read(names["info.dat"]).decode("utf-8-sig"))
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
                m = metrics(notes_of(json.loads(z.read(names[fn.lower()]).decode("utf-8-sig"))), bpm)
                if m:
                    rows.append({"id": mid, "diff": diff, **m, **ratings.get(diff, {})})
        except Exception as e:
            print("zip fail", mid, e, file=sys.stderr)
    json.dump(rows, open(OUT, "w"))
    print("ok", len(rows), sum(1 for r in rows if r.get("techRating")))


if __name__ == "__main__":
    main()

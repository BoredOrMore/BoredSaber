"""Measure reaction time (RT) and same-hand swing gap per difficulty from BeatSaver maps.

RT uses the same half-jump formula as game/Map.gd (Beat Saber's): start at 4 beats,
halve while njs * spb * hjd > 17.999, add the offset, floor at 0.25 beats.
Swing gap = time between consecutive notes of the same hand, ignoring stacked/slider
notes closer than STACK_S. Downloads go to a separate data dir; this script never runs them.
"""
import io, json, os, statistics, sys, time, urllib.request, zipfile

DATA = sys.argv[1]
PAGES = int(sys.argv[2])
ZIP_SAMPLE_PER_SOURCE = int(sys.argv[3])
STACK_S = 0.05
DIFFS = ["Easy", "Normal", "Hard", "Expert", "ExpertPlus"]


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": "BoredSaber-research/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        b = r.read()
    return b if binary else json.loads(b)


def rt_seconds(bpm, njs, offset):
    if njs <= 0 or bpm <= 0:
        return None
    spb = 60.0 / bpm
    hjd = 4.0
    while njs * spb * hjd > 17.999:
        hjd /= 2.0
    return max(hjd + offset, 0.25) * spb


def note_times(diff_json):
    """Return {hand: [beat,...]} for v2/v3/v4 difficulty JSON."""
    hands = {0: [], 1: []}
    if "_notes" in diff_json:
        for n in diff_json["_notes"]:
            if isinstance(n, dict) and n.get("_type") in (0, 1):
                hands[n["_type"]].append(float(n.get("_time", 0)))
    elif "colorNotes" in diff_json:
        data = diff_json.get("colorNotesData")
        for n in diff_json["colorNotes"]:
            if not isinstance(n, dict):
                continue
            if data is not None:  # v4: index into data array
                c = data[n.get("i", 0)].get("c", 0) if n.get("i", 0) < len(data) else 0
            else:
                c = n.get("c", 0)
            if c in (0, 1):
                hands[c].append(float(n.get("b", 0)))
    return hands


def swing_gaps(hands, bpm):
    gaps = []
    spb = 60.0 / bpm
    for beats in hands.values():
        beats.sort()
        last = None
        for b in beats:
            if last is not None:
                g = (b - last) * spb
                if g >= STACK_S:
                    gaps.append(g)
                    last = b
            else:
                last = b
    return gaps


def collect(source, url_fmt):
    rows, maps = [], []
    for p in range(PAGES):
        try:
            d = get(url_fmt.format(p))
        except Exception as e:
            print("page fail", source, p, e, file=sys.stderr)
            break
        for m in d.get("docs", []):
            bpm = m["metadata"].get("bpm") or 0
            v = m["versions"][0] if m.get("versions") else None
            if not v or bpm <= 0:
                continue
            maps.append((m["id"], bpm, v))
            for df in v.get("diffs", []):
                if df.get("characteristic") != "Standard" or df.get("difficulty") not in DIFFS:
                    continue
                rt = rt_seconds(bpm, df.get("njs", 0), df.get("offset", 0))
                rows.append({"source": source, "id": m["id"], "diff": df["difficulty"], "bpm": bpm,
                             "njs": df.get("njs"), "offset": df.get("offset"), "rt": rt,
                             "nps": df.get("nps"), "stars": df.get("blStars") or df.get("stars")})
        time.sleep(0.4)
    return rows, maps


def zip_gaps(source, maps):
    rows = []
    for mid, bpm, v in maps[:ZIP_SAMPLE_PER_SOURCE]:
        path = os.path.join(DATA, mid + ".zip")
        try:
            if not os.path.exists(path):
                with open(path, "wb") as f:
                    f.write(get(v["downloadURL"], binary=True))
            z = zipfile.ZipFile(path)
            names = {n.lower(): n for n in z.namelist()}
            info_name = names.get("info.dat")
            info = json.loads(z.read(info_name).decode("utf-8-sig"))
            files = {}
            for s in info.get("_difficultyBeatmapSets", []):
                if s.get("_beatmapCharacteristicName") == "Standard":
                    for b in s.get("_difficultyBeatmaps", []):
                        files[b["_difficulty"]] = b["_beatmapFilename"]
            for b in info.get("difficultyBeatmaps", []):  # v4 info
                if b.get("characteristic") == "Standard":
                    files[b["difficulty"]] = b.get("beatmapDataFilename")
            for diff, fn in files.items():
                if diff not in DIFFS or not fn or fn.lower() not in names:
                    continue
                dj = json.loads(z.read(names[fn.lower()]).decode("utf-8-sig"))
                gaps = swing_gaps(note_times(dj), bpm)
                if len(gaps) < 20:
                    continue
                gaps.sort()
                rows.append({"source": source, "id": mid, "diff": diff,
                             "gap_med": statistics.median(gaps),
                             "gap_p10": gaps[len(gaps) // 10]})
        except Exception as e:
            print("zip fail", mid, e, file=sys.stderr)
        time.sleep(0.3)
    return rows


def main():
    os.makedirs(DATA, exist_ok=True)
    out = {"rt": [], "gaps": []}
    for source, url in [
        ("ranked", "https://api.beatsaver.com/search/text/{}?sortOrder=Rating&ranked=true"),
        ("popular", "https://api.beatsaver.com/search/text/{}?sortOrder=Rating"),
    ]:
        rows, maps = collect(source, url)
        out["rt"] += rows
        out["gaps"] += zip_gaps(source, maps)
        print(source, len(rows), "diff rows", file=sys.stderr)
    json.dump(out, open(os.path.join(DATA, "results.json"), "w"))
    print("ok", len(out["rt"]), len(out["gaps"]))


main()

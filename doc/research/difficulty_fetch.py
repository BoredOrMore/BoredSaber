"""Difficulty rating research (doc/research/difficulty-rating.md): fetches popular BeatSaver maps (Standard difficulties)
and BeatLeader's ratings for each, and keeps their notes as one JSON line per map. Downloads go to a separate data dir.
Usage: python3 -I difficulty_fetch.py <out.jsonl> <pages of 20> [extra BeatSaver ids, comma separated]
"""
import io, json, os, sys, time, urllib.request, zipfile
OUT = sys.argv[1]; PAGES = int(sys.argv[2]); EXTRA = sys.argv[3].split(",") if len(sys.argv) > 3 else []
def get(url, binary=False):
    for t in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "BoredSaber-research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                b = r.read()
            return b if binary else json.loads(b)
        except Exception as e:
            err = e; time.sleep(2 ** t)
    raise err
def notes_of(dj):
    out, bombs = [], 0
    if "_notes" in dj:
        for n in dj["_notes"]:
            if not isinstance(n, dict): continue
            t = n.get("_type")
            if t in (0, 1): out.append([float(n.get("_time", 0)), t, int(n.get("_lineIndex", 0)), int(n.get("_lineLayer", 0)), int(n.get("_cutDirection", 8))])
            elif t == 3: bombs += 1
    else:
        data = dj.get("colorNotesData")
        for n in dj.get("colorNotes", []):
            if not isinstance(n, dict): continue
            src = n
            if data is not None and 0 <= n.get("i", -1) < len(data): src = data[n["i"]]
            c = src.get("c", -1)
            if c in (0, 1): out.append([float(n.get("b", 0)), c, int(src.get("x", 0)), int(src.get("y", 0)), int(src.get("d", 8))])
        bombs = len(dj.get("bombNotes", []))
    return out, bombs
done = set()
if os.path.exists(OUT):
    for line in open(OUT): done.add(json.loads(line)["id"])
maps = []
for p in range(PAGES):
    maps += get(f"https://api.beatsaver.com/search/text/{p}?sortOrder=Rating")["docs"]; time.sleep(0.3)
for mid in EXTRA:
    maps.append(get(f"https://api.beatsaver.com/maps/id/{mid}"))
with open(OUT, "a") as f:
    for m in maps:
        if m["id"] in done: continue
        done.add(m["id"])
        try:
            v = m["versions"][0]; h = v["hash"]
            ratings = {}
            try:
                for lb in get("https://api.beatleader.xyz/leaderboards/hash/" + h).get("leaderboards", []):
                    d = lb["difficulty"]
                    if d.get("modeName") == "Standard":
                        ratings[d["difficultyName"]] = {k: d.get(k) for k in ("stars", "passRating", "accRating", "techRating", "status")}
            except Exception as e:
                print("bl fail", m["id"], e, file=sys.stderr)
            z = zipfile.ZipFile(io.BytesIO(get(v["downloadURL"], True)))
            names = {n.lower(): n for n in z.namelist()}
            info = json.loads(z.read(names["info.dat"]).decode("utf-8-sig"))
            bpm = info.get("_beatsPerMinute") or info.get("audio", {}).get("bpm")
            files = {}
            for s in info.get("_difficultyBeatmapSets", []):
                if s.get("_beatmapCharacteristicName") == "Standard":
                    for d in s["_difficultyBeatmaps"]:
                        files[d["_difficulty"]] = (d["_beatmapFilename"], d.get("_noteJumpMovementSpeed", 0), d.get("_noteJumpStartBeatOffset", 0))
            for d in info.get("difficultyBeatmaps", []):
                if d.get("characteristic") == "Standard":
                    files[d["difficulty"]] = (d["beatmapDataFilename"], d.get("noteJumpMovementSpeed", 0), d.get("noteJumpStartBeatOffset", 0))
            diffs = {}
            for name, (fn, njs, off) in files.items():
                if fn.lower() not in names: continue
                notes, bombs = notes_of(json.loads(z.read(names[fn.lower()]).decode("utf-8-sig")))
                diffs[name] = {"njs": njs, "offset": off, "notes": notes, "bombs": bombs}
            f.write(json.dumps({"id": m["id"], "name": m["name"], "bpm": bpm, "ranked_bl": m.get("blRanked", False), "diffs": diffs, "bl": ratings}) + "\n"); f.flush()
        except Exception as e:
            print("fail", m["id"], e, file=sys.stderr)
        time.sleep(0.2)
print("done", len(done))

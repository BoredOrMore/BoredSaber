"""Fits Get songs' fallback estimate: BeatLeader stars from BeatSaver's map data alone (doc/research/difficulty-rating.md).

Reads rows.json from difficulty_fit.py (one row per difficulty with its BeatLeader stars and reaction time), fetches
each map's BeatSaver document (api.beatsaver.com), then fits stars on BeatSaver's per-difficulty numbers with 5-fold
cross-validation grouped by map and compares the levels with the old estimate.

Usage: python3 difficulty_fit_beatsaver.py <data dir with rows.json and maps.jsonl>
"""
import json, os, random, sys, time, urllib.request
import numpy as np

CUTS = [3.94, 4.59, 5.49, 6.64]
RT = [1.04, 0.903, 0.776, 0.645]
GAP = [0.866, 0.646, 0.496, 0.383]


def level(stars):
    return sum(stars >= c for c in CUTS)


def threshold_level(x, tops):
    for i, v in enumerate(tops):
        if x >= v:
            return i
    return 4


def beatsaver_docs(data_dir):
    path = os.path.join(data_dir, "bs_docs.jsonl")
    if not os.path.exists(path):
        with open(path, "w") as out:
            for line in open(os.path.join(data_dir, "maps.jsonl")):
                map_id = json.loads(line)["id"]
                for attempt in range(4):
                    try:
                        request = urllib.request.Request(f"https://api.beatsaver.com/maps/id/{map_id}",
                                                         headers={"User-Agent": "difficulty-research"})
                        with urllib.request.urlopen(request, timeout=20) as r:
                            out.write(r.read().decode().replace("\n", " ") + "\n")
                        break
                    except Exception:
                        time.sleep(2 ** attempt)
                time.sleep(0.2)
    return {d["id"]: d for d in map(json.loads, open(path))}


def main(data_dir):
    docs = beatsaver_docs(data_dir)
    data = []
    for r in json.load(open(os.path.join(data_dir, "rows.json"))):
        doc = docs.get(r["id"])
        diffs = [x for x in doc["versions"][0]["diffs"] if x.get("characteristic", "Standard") == "Standard"
                 and x["difficulty"] == r["diff"]] if doc else []
        if not diffs:
            continue
        x = diffs[0]
        notes = max(x.get("notes", 0), 1)
        old = threshold_level(r["rt"], RT)
        if x.get("nps", 0) > 0:
            old = max(old, threshold_level(0.82 * 2 / x["nps"], GAP))
        data.append(dict(id=r["id"], stars=r["stars"], old=min(old, 4), nps=x.get("nps", 0), njs=x.get("njs", 0),
                         warn=100 * x.get("paritySummary", {}).get("warns", 0) / notes))
    ids = sorted({r["id"] for r in data})
    random.Random(1).shuffle(ids)
    fold = {m: i % 5 for i, m in enumerate(ids)}
    row = lambda r: [1.0, r["nps"], r["njs"], r["warn"]]
    y = np.array([r["stars"] for r in data])
    predicted = np.zeros(len(data))
    for k in range(5):
        train = [i for i, r in enumerate(data) if fold[r["id"]] != k]
        w = np.linalg.lstsq(np.array([row(data[i]) for i in train]), y[train], rcond=None)[0]
        for i, r in enumerate(data):
            if fold[r["id"]] == k:
                predicted[i] = np.dot(w, row(r))
    truth = [level(s) for s in y]
    for name, levels in [("old", [r["old"] for r in data]), ("refit", [level(p) for p in predicted])]:
        same = np.mean([a == b for a, b in zip(levels, truth)])
        harder = np.mean([a > b for a, b in zip(levels, truth)])
        far = sum(abs(a - b) >= 2 for a, b in zip(levels, truth))
        print(f"{name}: same {same:.1%} harder {harder:.1%} easier {1 - same - harder:.1%} off by 2+ {far}")
    print("R2", 1 - ((y - predicted) ** 2).sum() / ((y - y.mean()) ** 2).sum())
    print("weights (base, nps, njs, warn %)", np.linalg.lstsq(np.array([row(r) for r in data]), y, rcond=None)[0])
    print("NJS 5/95 %", np.percentile([r["njs"] for r in data], [5, 95]),
          "warn 5/95 %", np.percentile([r["warn"] for r in data], [5, 95]))


if __name__ == "__main__":
    main(sys.argv[1])

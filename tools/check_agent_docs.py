#!/usr/bin/env python3
"""Fails when a script, scene or shader is not named in the AGENTS.md that covers it.

The covering doc is the nearest AGENTS.md in the file's folder or above it (the root one excluded, so every code
folder sits under a folder doc). A file counts as named when its name, with any of the code extensions, appears in
the doc: `ComboHud.gd` covers ComboHud.gd, ComboHud.tscn and ComboHud.gdshader.
Run from the repo root: python3 tools/check_agent_docs.py
"""
import re
import subprocess
import sys
from pathlib import Path

CODE = (".gd", ".tscn", ".gdshader", ".gdshaderinc")
ROOTS = ("game/", "tests/", "tools/")


def covering_doc(path: Path) -> Path | None:
    for folder in path.parents:
        if folder == Path("."):
            return None
        doc = folder / "AGENTS.md"
        if doc.is_file():
            return doc
    return None


def main() -> int:
    tracked = subprocess.run(["git", "ls-files", *ROOTS], capture_output=True, text=True, check=True).stdout.split()
    texts: dict[Path, str] = {}
    missing: dict[str, list[str]] = {}
    for name in tracked:
        path = Path(name)
        if path.suffix not in CODE or "asset_pipeline" in path.parts:
            continue
        doc = covering_doc(path)
        if doc is None:
            missing.setdefault("(no folder AGENTS.md)", []).append(name)
            continue
        text = texts.setdefault(doc, doc.read_text())
        named = re.compile(r"(?<![\w-])" + re.escape(path.stem) + r"\.(?:gd|tscn|gdshader|gdshaderinc)\b")
        if not named.search(text):
            missing.setdefault(str(doc), []).append(name)
    for doc, files in missing.items():
        print(f"{doc} does not name:")
        for f in sorted(files):
            print(f"  {f}")
    if missing:
        print("Name each file in the AGENTS.md that covers it (what it does, in a line).")
        return 1
    print("check_agent_docs: every script, scene and shader is named in its folder's AGENTS.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())

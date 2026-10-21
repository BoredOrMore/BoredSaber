#!/usr/bin/env python3
"""Generates sounds with Stable Audio 3 Small SFX, with one fixed recipe so a rerun gives the same files.

Each sound has a short prompt naming one event, a seed and a length; every prompt ends with the same STYLE and
shares NEGATIVE, STEPS and CFG_SCALE so the set stays one family. A run writes BATCH candidates, all through
the same post chain: mono, trim leading silence, cut to length, fade out, optional code-made layer mixed in,
high-pass below 30 Hz only (the sub stays), 44.1 kHz 16-bit, gain to TARGET_LUFS with true peak at most
PEAK_DBTP. Files stay dry: the Stinger bus adds the room.

fail: the song is lost. The sabers power down (Stable Audio), then one clean sub thump (synthesised here, like
    low_health in tools/make_feedback_sounds.py). 1.3 s, so it ends before the song's 1.5 s wind-down.
    A long "distorted glitch" prompt sounded like a jackhammer; keep prompts to one event. The first saber prompt
    came out shrill, so the prompt asks for a low hum and each candidate comes in TONES (darker by letter).

Needs Stable Audio 3 (github.com/Stability-AI/stable-audio-3, weights under the Stability AI Community License)
installed in SA3_DIR, and ffmpeg. Not a game dependency: only this tool uses it.
    python3 tools/make_sa3_sounds.py fail            # candidates in OUT_DIR/fail/, listen and pick one
    python3 tools/make_sa3_sounds.py fail --pick 2b  # copies candidate 2, tone b to game/data/fail.wav
"""
import argparse
import json
import math
import os
import re
import shutil
import struct
import subprocess
import wave
from pathlib import Path

SA3_DIR = Path(os.environ.get("SA3_DIR", "~/ai-audio-tools/stable-audio-3")).expanduser()
OUT_DIR = Path(os.environ.get("SA3_OUT", "~/ai-audio-tools/samples")).expanduser()
GAME_DATA = Path(__file__).resolve().parent.parent / "game" / "data"
RATE = 44100

MODEL = "small-sfx"
STEPS = 8
CFG_SCALE = 1.0
BATCH = 3
STYLE = "sci-fi game sound effect, single clean event, high quality, dry, no reverb"
NEGATIVE = ("noise, rattle, drill, jackhammer, distortion, glitch, high-pitched, whine, shrill, squeal, music, "
            "melody, jingle, chime, bells, vocals, speech")
TARGET_LUFS = -18.0
PEAK_DBTP = -1.0
FADE_SECONDS = 0.15
# tone treatments of the Stable Audio layer, each candidate gets all of them:
# letter: (pitch shift in semitones, low-pass Hz, high-shelf gain dB above SHELF_HZ)
TONES = {"a": (0, 4000, 0.0), "b": (-5, 3000, -3.0), "c": (-9, 2000, -6.0)}
SHELF_HZ = 1500

SOUNDS = {
    "fail": {
        "prompt": "lightsaber powering down, low deep warm hum winding down and switching off",
        "seed": 2024,
        # the Stable Audio layer is cut to this long
        "layer_seconds": 0.75,
        "seconds": 1.3,
        # the thump lands as the power-down ends: (start s, from Hz, to Hz, length s, decay s, gain dB). It starts
        # at 130 Hz because the Pico 4 speakers barely play below ~80 Hz; headphones still get the drop to 45 Hz.
        "thump": (0.55, 130.0, 45.0, 0.6, 0.18, 0.0),
    },
}


def ffmpeg(*args: str) -> str:
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y", *args], check=True,
                          capture_output=True, text=True).stderr


def write_thump(path: Path, from_hz: float, to_hz: float, seconds: float, decay: float) -> None:
    """A sine gliding exponentially down, with a 5 ms attack: a clean sub thump with no noise."""
    out, phase = [], 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        phase += 2 * math.pi * from_hz * (to_hz / from_hz) ** (t / seconds) / RATE
        out.append(min(t / 0.005, 1.0) * math.sin(phase) * math.exp(-t / decay))
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(v * 32767 * 0.9)) for v in out))


def post(raw: Path, out: Path, sound: dict, thump: Path | None, tone: tuple) -> None:
    """The shared post chain, with the gain measured on the finished mix so every sound lands on TARGET_LUFS."""
    seconds = sound["seconds"]
    semitones, lowpass_hz, shelf_db = tone
    ratio = 2 ** (semitones / 12)
    # asetrate shifts pitch and length together; atempo puts the length back
    layer = (f"[0:a]aformat=sample_rates={RATE}:channel_layouts=mono,asetrate={RATE * ratio:.0f},"
             f"aresample={RATE},atempo={1 / ratio:.4f},lowpass=f={lowpass_hz},"
             f"highshelf=f={SHELF_HZ}:g={shelf_db},"
             f"silenceremove=start_periods=1:start_threshold=-50dB,atrim=0:{sound['layer_seconds']},"
             f"afade=t=out:st={sound['layer_seconds'] - FADE_SECONDS}:d={FADE_SECONDS}[l]")
    inputs = ["-i", str(raw)]
    if thump:
        start, _, _, _, _, gain_db = sound["thump"]
        inputs += ["-i", str(thump)]
        layer = layer[:-3] + (f"[s];[1:a]aformat=sample_rates={RATE}:channel_layouts=mono,adelay={int(start * 1000)},"
                              f"volume={gain_db}dB[t];[s][t]amix=inputs=2:normalize=0:duration=longest[l]")
    shape = (f"{layer};[l]apad,atrim=0:{seconds},afade=t=out:st={seconds - FADE_SECONDS}:d={FADE_SECONDS},"
             f"highpass=f=30")
    stats = ffmpeg(*inputs, "-filter_complex", f"{shape},loudnorm=I={TARGET_LUFS}:TP={PEAK_DBTP}:print_format=json",
                   "-f", "null", "-")
    measured = json.loads(stats[stats.rindex("{"):stats.rindex("}") + 1])
    gain = TARGET_LUFS - float(measured["input_i"])
    # never let the gain push the true peak over PEAK_DBTP; a short hit then sits under the target instead
    gain = min(gain, PEAK_DBTP - float(measured["input_tp"]))
    ffmpeg(*inputs, "-filter_complex", f"{shape},volume={gain:.2f}dB", "-ar", str(RATE), "-c:a", "pcm_s16le",
           str(out))


def generate(name: str) -> None:
    sound = SOUNDS[name]
    folder = OUT_DIR / name
    raw_dir = folder / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(SA3_DIR / ".venv" / "bin" / "stable-audio"), "--model", MODEL, "--steps", str(STEPS),
                    "--cfg-scale", str(CFG_SCALE), "--seed", str(sound["seed"]), "--batch-size", str(BATCH),
                    "--duration", str(sound["layer_seconds"] + 0.5), "-p", f"{sound['prompt']}, {STYLE}",
                    "--negative-prompt", NEGATIVE, "-o", str(raw_dir / f"{name}.wav")], check=True)
    thump = None
    if "thump" in sound:
        thump = raw_dir / "thump.wav"
        write_thump(thump, *sound["thump"][1:5])
    for i in range(BATCH):
        for letter, tone in TONES.items():
            out = folder / f"{name}_{i + 1}{letter}.wav"
            post(raw_dir / f"{name}_{i}.wav", out, sound, thump, tone)
            loud = ffmpeg("-i", str(out), "-af", "ebur128=peak=true", "-f", "null", "-")
            i_lufs = re.findall(r"I:\s+(-?[\d.]+) LUFS", loud)[-1]
            peak = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", loud)[-1]
            print(out, f"{i_lufs} LUFS, true peak {peak} dBTP")


parser = argparse.ArgumentParser()
parser.add_argument("sound", choices=SOUNDS)
parser.add_argument("--pick", help="copy this candidate (number and tone letter, e.g. 2b) into game/data")
args = parser.parse_args()
if args.pick:
    shutil.copyfile(OUT_DIR / args.sound / f"{args.sound}_{args.pick}.wav", GAME_DATA / f"{args.sound}.wav")
    print(GAME_DATA / f"{args.sound}.wav")
else:
    generate(args.sound)

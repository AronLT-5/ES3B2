#!/usr/bin/env python3
"""PNG -> RGB444 .mem converter for Serpent Says sprite ROMs.

Each output line is a 3-character lowercase hex string representing one
12-bit RGB444 pixel, written row-major (top-left first).  Pixels with
alpha < 128 are emitted as ``000`` -- the project-wide transparent key.

Usage
-----
Single file:
    python png_to_mem.py [--scale WxH] [--filter lanczos|bilinear|nearest] INPUT.png OUTPUT.mem

Batch (regenerate every sprite this overhaul touched):
    python png_to_mem.py --all
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from typing import Optional

try:
    from PIL import Image
except ImportError:
    sys.stderr.write(
        "ERROR: Pillow is required.  Install it with `pip install pillow` and re-run.\n"
    )
    sys.exit(1)


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
PNG_DIR = os.path.join(PROJECT_DIR, "Sprites", "PNG")
MEM_DIR = os.path.join(PROJECT_DIR, "Sprites", "mem")

ALPHA_THRESHOLD = 128

FILTERS = {
    "lanczos":  Image.Resampling.LANCZOS,
    "bilinear": Image.Resampling.BILINEAR,
    "nearest":  Image.Resampling.NEAREST,
}


@dataclass(frozen=True)
class Conversion:
    src: str
    dst: str
    size: Optional[tuple]  # (w, h) or None to keep source size
    filt: str


# Canonical conversions for the title-screen + grass overhaul.
ALL_CONVERSIONS = (
    Conversion("new_grass_cold.png",   "Grass_Cold.mem",      None,        "nearest"),
    Conversion("new_grass_normal.png", "Grass_Normal.mem",    None,        "nearest"),
    Conversion("new_grass_hot.png",    "Grass_Hot.mem",       None,        "nearest"),
    Conversion("TitleText.png",        "TitleText.mem",       (500, 73),   "lanczos"),
    Conversion("TitleScreenNew.png",   "TitleScreenNew.mem",  (480, 270),  "lanczos"),
)


def parse_scale(s: str) -> tuple:
    try:
        w_str, h_str = s.lower().split("x")
        return int(w_str), int(h_str)
    except (ValueError, AttributeError):
        raise argparse.ArgumentTypeError(
            f"--scale expected WxH (e.g. 480x270), got {s!r}"
        )


def convert(src_path: str, dst_path: str, size, filt: str) -> int:
    img = Image.open(src_path).convert("RGBA")
    if size is not None and img.size != size:
        img = img.resize(size, FILTERS[filt])
    w, h = img.size
    print(f"  {os.path.basename(src_path):28s} -> "
          f"{os.path.basename(dst_path):24s}  {w}x{h}  ({filt})")

    pixels = img.load()
    os.makedirs(os.path.dirname(dst_path) or ".", exist_ok=True)
    with open(dst_path, "w", encoding="ascii", newline="\n") as f:
        for y in range(h):
            for x in range(w):
                r, g, b, a = pixels[x, y]
                if a < ALPHA_THRESHOLD:
                    f.write("000\n")
                else:
                    f.write(f"{r >> 4:x}{g >> 4:x}{b >> 4:x}\n")
    return w * h


def run_all() -> None:
    print(f"Pillow {Image.__version__}")
    print(f"PNG dir: {PNG_DIR}")
    print(f"MEM dir: {MEM_DIR}\n")
    total = 0
    for c in ALL_CONVERSIONS:
        src = os.path.join(PNG_DIR, c.src)
        dst = os.path.join(MEM_DIR, c.dst)
        if not os.path.exists(src):
            print(f"  WARNING: missing source {src}", file=sys.stderr)
            continue
        total += convert(src, dst, c.size, c.filt)
    print(f"\nTotal pixels written: {total}")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", nargs="?", help="Input PNG path")
    p.add_argument("output", nargs="?", help="Output .mem path")
    p.add_argument("--scale", type=parse_scale,
                   help="Resize source to WxH (e.g. 480x270) before encoding")
    p.add_argument("--filter", choices=tuple(FILTERS.keys()), default="lanczos",
                   help="Resampling filter when --scale is set (default: lanczos)")
    p.add_argument("--all", action="store_true",
                   help="Run the canonical project conversions and exit")
    args = p.parse_args(argv)

    if args.all:
        run_all()
        return 0

    if not (args.input and args.output):
        p.error("INPUT and OUTPUT are required unless --all is given")

    convert(args.input, args.output, args.scale, args.filter)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate / preview Huawei OLED animation XML files (welcome, ani_power_off).

Format: 1 bit per pixel, row-major, MSB = leftmost pixel, 16 bytes per row for
a 128 px wide screen. A 0 bit is a lit pixel, a 1 bit is dark (0xFF = black),
same as the stock files.

Usage:
  oled_anim.py preview  <file.xml> [<file.xml> ...] -o preview.png
  oled_anim.py decode   <file.xml> -o frame.png
  oled_anim.py encode   --tag welcome --frequency 1000 -o out.xml f1.png [f2.png ...]
"""
import argparse
import re
import sys

from PIL import Image

W, H = 128, 128


def frames_from_xml(path):
    s = open(path).read()
    w = int(re.search(r"<width>(\d+)", s).group(1))
    h = int(re.search(r"<height>(\d+)", s).group(1))
    frames = []
    for fr in re.findall(r"<frame>(.*?)</frame>", s, re.S):
        data = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", fr)]
        if len(data) != w * h // 8:
            raise ValueError(f"{path}: frame has {len(data)} bytes, expected {w * h // 8}")
        im = Image.new("1", (w, h), 0)
        px = im.load()
        for y in range(h):
            for x in range(w):
                bit = (data[y * (w // 8) + x // 8] >> (7 - x % 8)) & 1
                px[x, y] = 0 if bit else 1  # 0 bit = lit
        frames.append(im)
    return frames


def image_to_bytes(im):
    im = im.convert("1")
    if im.size != (W, H):
        raise ValueError(f"frame must be {W}x{H}, got {im.size}")
    px = im.load()
    out = []
    for y in range(H):
        for xb in range(W // 8):
            byte = 0
            for i in range(8):
                lit = px[xb * 8 + i, y] != 0
                byte = (byte << 1) | (0 if lit else 1)
            out.append(byte)
    return out


def frames_to_xml(tag, frames, frequency, repeat=0, priority=30):
    # Field order copied from the stock files (welcome has <code> twice).
    size = W * H // 8
    parts = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<config>",
        f"<{tag}>",
        "<enable>1</enable>",
        "<sx>0</sx>",
        "<sy>0</sy>",
    ]
    if tag == "welcome":
        parts.append("<code>0</code>")
    parts += [
        f"<height>{H}</height>",
        f"<width>{W}</width>",
        f"<size>{size}</size>",
        "<bmp_current>0</bmp_current>",
        f"<bmp_total>{len(frames)}</bmp_total>",
        "<code>0</code>",
        f"<repeat>{repeat}</repeat>",
        f"<priority>{priority}</priority>",
        f"<frequency>{frequency}</frequency>",
        "<bitmap>",
    ]
    for im in frames:
        data = image_to_bytes(im)
        rows = [",".join(f"0x{b:02X}" for b in data[i:i + 16]) + "," for i in range(0, len(data), 16)]
        parts.append("<frame>\n" + "\n".join(rows) + "</frame>")
    parts += ["</bitmap>", f"</{tag}>", "</config>", ""]
    return "\n".join(parts)


def preview(frame_lists, out, scale=3, gap=12):
    """frame_lists: list of rows, each a list of 1-bit frames."""
    cols = max(len(r) for r in frame_lists)
    cw, ch = W * scale, H * scale
    sheet = Image.new("RGB", (cols * (cw + gap) + gap, len(frame_lists) * (ch + gap) + gap), (90, 90, 90))
    for r, row in enumerate(frame_lists):
        for c, im in enumerate(row):
            big = im.convert("L").resize((cw, ch), Image.NEAREST)
            tinted = Image.merge("RGB", (big, big, big))
            sheet.paste(tinted, (gap + c * (cw + gap), gap + r * (ch + gap)))
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("preview")
    p.add_argument("xml", nargs="+")
    p.add_argument("-o", "--out", required=True)

    d = sub.add_parser("decode")
    d.add_argument("xml")
    d.add_argument("-o", "--out", required=True)

    e = sub.add_parser("encode")
    e.add_argument("--tag", required=True, choices=["welcome", "ani_power_off"])
    e.add_argument("--frequency", type=int, default=1000, help="ms per frame")
    e.add_argument("-o", "--out", required=True)
    e.add_argument("png", nargs="+")

    a = ap.parse_args()
    if a.cmd == "preview":
        preview([frames_from_xml(x) for x in a.xml], a.out)
    elif a.cmd == "decode":
        frames_from_xml(a.xml)[0].convert("L").save(a.out)
    elif a.cmd == "encode":
        frames = [Image.open(p) for p in a.png]
        open(a.out, "w").write(frames_to_xml(a.tag, frames, a.frequency))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""SPEC B.9 — the app icon.

Deep #0A1418 ground, one geometric mark: the OBD2 connector trapezoid with a
rising diagnostic line, in #FFB020. No text, no wrench, no car, no gloss.
Renders the iOS appiconset, the Android legacy mipmaps, and the adaptive
foreground (mark inside the 66dp safe circle of the 108dp canvas).
"""
import json, os
from PIL import Image, ImageDraw

GROUND = (0x0A, 0x14, 0x18, 255)
AMBER = (0xFF, 0xB0, 0x20, 255)
ROOT = os.path.join(os.path.dirname(__file__), '..')


def mark(size, scale=1.0, ground=True):
    """The mark on a square canvas of `size` px; `scale` shrinks it for the
    adaptive safe zone. Drawn at 4× and downsampled for clean edges."""
    S = size * 4
    img = Image.new('RGBA', (S, S), GROUND if ground else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    u = S * 0.5 * scale                      # half-extent of the mark box
    stroke = max(2, int(S * 0.055 * scale))
    r = stroke / 2
    # J1962 connector: wider top, narrower bottom, sides angled ~14°.
    top_w, bot_w, h = 0.66 * u, 0.50 * u, 0.62 * u
    y0, y1 = c - h * 0.52, c + h * 0.48
    corners = [(c - top_w, y0), (c + top_w, y0), (c + bot_w, y1), (c - bot_w, y1)]
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        d.line([a, b], fill=AMBER, width=stroke)
    for (x, y) in corners:                   # round the joints
        d.ellipse([x - r, y - r, x + r, y + r], fill=AMBER)
    # The rising diagnostic line: flat, then up and to the right.
    pad = stroke * 2.2
    lx0, lx1 = c - bot_w + pad, c + bot_w - pad
    ly_base, ly_top = y1 - pad, y0 + pad * 1.1
    pts = [(lx0, ly_base), (lx0 + (lx1 - lx0) * 0.42, ly_base), (lx1, ly_top)]
    d.line(pts, fill=AMBER, width=stroke, joint='curve')
    for (x, y) in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=AMBER)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG', optimize=True)


def ios():
    d = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    meta = json.load(open(os.path.join(d, 'Contents.json')))
    master = mark(1024)
    for e in meta['images']:
        pts = float(e['size'].split('x')[0]); sc = int(e['scale'][0])
        px = int(round(pts * sc))
        # No alpha on iOS: App Store Connect rejects a marketing icon with one.
        save(master.resize((px, px), Image.LANCZOS).convert('RGB'), os.path.join(d, e['filename']))
    return len(meta['images'])


def android():
    res = os.path.join(ROOT, 'android/app/src/main/res')
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    master = mark(1024)
    for name, k in dens.items():
        # Legacy launcher: 48dp with the ground.
        save(master.resize((int(48 * k), int(48 * k)), Image.LANCZOS).convert('RGB'),
             os.path.join(res, f'mipmap-{name}', 'ic_launcher.png'))
        # Adaptive foreground: 108dp canvas; the painted mark (~66% x 31% of
        # its box) fills the 66dp safe circle at this scale, so it reads at
        # the same size as the legacy icon once the launcher masks it.
        fg = mark(int(108 * k), scale=0.81, ground=False)
        save(fg, os.path.join(res, f'mipmap-{name}', 'ic_launcher_foreground.png'))
    os.makedirs(os.path.join(res, 'mipmap-anydpi-v26'), exist_ok=True)
    open(os.path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    os.makedirs(os.path.join(res, 'values'), exist_ok=True)
    open(os.path.join(res, 'values', 'ic_launcher_background.xml'), 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#0A1418</color>\n</resources>\n')


if __name__ == '__main__':
    n = ios(); android()
    print(f'icon: {n} iOS sizes, 5 Android densities + adaptive')

"""Splits a Brunchy logo image into named parts by its flat colours.

Two logos (BRUNCHY_PROFILE):
  student (default)  D:/Brunchy/app icon/original/brunchy-logo-round.jpeg   yellow disc, no smile, cheese = disc showing through
  vendor             D:/Brunchy/app icon/original/brunchy-vendor-logo.png   glossy aqua disc, smile, yellow cheese, "— Vendor —"

The source is upscaled 3x first: compression noise averages out and the traced outlines come out smooth.
Parts are found by shape and position, not fixed pixel windows.
"""
import os
import numpy as np
from PIL import Image
from tracer import components

PROFILE = os.environ.get('BRUNCHY_PROFILE', 'student')
UP = 3
if PROFILE == 'vendor':
    SRC = os.environ.get('BRUNCHY_LOGO', r'D:/Brunchy/app icon/original/brunchy-vendor-logo.png')
    # Several shades map to the same part (the disc is a gradient).
    PALETTE = [('white', (255, 255, 255)), ('disc', (40, 240, 226)), ('disc', (14, 229, 217)), ('disc', (1, 214, 208)),
               ('gloss', (125, 251, 241)), ('bun', (253, 110, 8)), ('seed', (253, 230, 132)), ('cheese', (253, 215, 59)),
               ('brown', (92, 36, 7))]
else:
    SRC = os.environ.get('BRUNCHY_LOGO', r'D:/Brunchy/app icon/original/brunchy-logo-round.jpeg')
    PALETTE = [('white', (255, 255, 255)), ('disc', (252, 204, 42)), ('bun', (254, 96, 9)), ('seed', (254, 221, 54)),
               ('brown', (93, 39, 15))]
NAMES = sorted({n for n, _ in PALETTE}, key=[n for n, _ in PALETTE].index)


def _labels():
    im = Image.open(SRC).convert('RGB')
    im = im.resize((im.width * UP, im.height * UP), Image.LANCZOS)
    a = np.asarray(im).astype(np.int32)
    best = np.full(a.shape[:2], 1 << 30, np.int64)
    lab = np.zeros(a.shape[:2], np.int8)
    for name, col in PALETTE:
        d = ((a - np.array(col)) ** 2).sum(-1)
        better = d < best
        lab[better] = NAMES.index(name)
        best[better] = d[better]
    return lab, a


label, rgb = _labels()
H, W = label.shape


def m(name):
    return label == NAMES.index(name)


def colour_of(mask):
    """Median colour of a part, as #RRGGBB (so the Lottie uses the logo's real colours)."""
    c = np.median(rgb[mask], 0).astype(int)
    return '#%02X%02X%02X' % tuple(c)


def fit_disc():
    """Least-squares circle through the boundary between the white surround and the logo."""
    inside = ~m('white')
    edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0) & np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
    ys, xs = np.nonzero(edge)
    keep = (xs > 5) & (xs < W - 5) & (ys > 5) & (ys < H - 5)
    x, y = xs[keep].astype(float), ys[keep].astype(float)
    for _ in range(2):  # fit, drop stray points (anti-alias halo, specks), refit
        A = np.c_[2 * x, 2 * y, np.ones(len(x))]
        cx, cy, c = np.linalg.lstsq(A, x ** 2 + y ** 2, rcond=None)[0]
        r = np.sqrt(c + cx ** 2 + cy ** 2)
        ok = np.abs(np.hypot(x - cx, y - cy) - r) < 6 * UP
        x, y = x[ok], y[ok]
    return cx, cy, r


def full(c):
    """Component (mask, x0, y0, n) -> full-frame boolean mask."""
    mk, x0, y0, _ = c
    out = np.zeros((H, W), bool)
    out[y0:y0 + mk.shape[0], x0:x0 + mk.shape[1]] = mk
    return out


def _inside(c, box):
    mk, x0, y0, _ = c
    bx0, by0, bx1, by1 = box
    return bx0 <= x0 and x0 + mk.shape[1] <= bx1 and by0 <= y0 and y0 + mk.shape[0] <= by1


def part_masks():
    p = {'disc': fit_disc()}
    buns = sorted(components(m('bun'), 5000), key=lambda c: -c[3])[:2]
    p['top_bun'], p['bottom_bun'] = sorted(buns, key=lambda c: c[2])
    tb, bb = p['top_bun'], p['bottom_bun']
    top_box = (tb[1], tb[2], tb[1] + tb[0].shape[1], tb[2] + tb[0].shape[0])
    bun_bottom = bb[2] + bb[0].shape[0]
    browns = components(m('brown'), 300 * UP * UP // 9)
    p['patty'] = max((c for c in browns if tb[2] < c[2] < bun_bottom and not _inside(c, top_box)), key=lambda c: c[3])
    below = [c for c in browns if c[2] >= bun_bottom - 20 * UP]
    if PROFILE == 'vendor':
        # "Brunchy" is the big letters; "— Vendor —" the small row underneath (letters + the two dashes).
        tall = max(c[0].shape[0] for c in below)
        p['letters'] = sorted((c for c in below if c[0].shape[0] > tall * 0.45), key=lambda c: c[1])
        word_bottom = max(c[2] + c[0].shape[0] for c in p['letters'])
        p['sub_letters'] = sorted((c for c in below if c[2] > word_bottom - 10 * UP and c[0].shape[0] <= tall * 0.45), key=lambda c: c[1])
        smiles = [c for c in browns if _inside(c, top_box)]
        p['smile'] = max(smiles, key=lambda c: c[3])
        p['cheese'] = max(components(m('cheese'), 2000), key=lambda c: c[3])
        gl = components(m('gloss'), 2000)
        p['gloss'] = max(gl, key=lambda c: c[3]) if gl else None
    else:
        p['letters'] = sorted((c for c in below if c[3] > 3000), key=lambda c: c[1])
    seeds = [c for c in components(m('seed'), 400) if _inside(c, top_box)]
    p['seeds'] = sorted(sorted(seeds, key=lambda c: -c[3])[:3], key=lambda c: c[1])
    return p


if __name__ == '__main__':
    p = part_masks()
    print(PROFILE, 'size', W, H, 'disc', [round(float(v), 1) for v in p['disc']])
    for k, v in p.items():
        if k == 'disc' or v is None: continue
        for c, x0, y0, n in (v if isinstance(v, list) else [v]):
            print(f'{k:11s} x0={x0:5d} y0={y0:5d} w={c.shape[1]:5d} h={c.shape[0]:5d} px={n}')

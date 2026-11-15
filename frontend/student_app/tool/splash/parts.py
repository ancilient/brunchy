"""Splits the real Brunchy logo (round version) into named parts by its flat colours.

The source is a 1254 px JPEG, so it is upscaled 3x first: compression noise averages out and the traced
outlines come out smooth. Parts are found by shape and position, not fixed pixel windows.
"""
import os
import numpy as np
from PIL import Image
from tracer import components

# The real logo, round version. Override with BRUNCHY_LOGO=/path/to/logo.
SRC = os.environ.get('BRUNCHY_LOGO', r'D:/Brunchy/app icon/original/brunchy-logo-round.jpeg')
UP = 3
PALETTE = {'white': (255, 255, 255), 'disc': (252, 204, 42), 'bun': (254, 96, 9), 'seed': (254, 221, 54), 'brown': (93, 39, 15)}
NAMES = list(PALETTE)


def _labels():
    im = Image.open(SRC).convert('RGB')
    im = im.resize((im.width * UP, im.height * UP), Image.LANCZOS)
    a = np.asarray(im).astype(np.int32)
    best = np.full(a.shape[:2], 1 << 30, np.int64)
    lab = np.zeros(a.shape[:2], np.int8)
    for i, n in enumerate(NAMES):
        d = ((a - np.array(PALETTE[n])) ** 2).sum(-1)
        better = d < best
        lab[better] = i
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
    A = np.c_[2 * x, 2 * y, np.ones(len(x))]
    cx, cy, c = np.linalg.lstsq(A, x ** 2 + y ** 2, rcond=None)[0]
    r = np.sqrt(c + cx ** 2 + cy ** 2)
    # drop stray points (anti-alias halo) and refit
    ok = np.abs(np.hypot(x - cx, y - cy) - r) < 6 * UP
    A, x, y = A[ok], x[ok], y[ok]
    cx, cy, c = np.linalg.lstsq(A, x ** 2 + y ** 2, rcond=None)[0]
    return cx, cy, np.sqrt(c + cx ** 2 + cy ** 2)


def full(c):
    """Component (mask, x0, y0, n) -> full-frame boolean mask."""
    mk, x0, y0, _ = c
    out = np.zeros((H, W), bool)
    out[y0:y0 + mk.shape[0], x0:x0 + mk.shape[1]] = mk
    return out


def part_masks():
    p = {'disc': fit_disc()}
    buns = sorted(components(m('bun'), 5000), key=lambda c: -c[3])[:2]
    p['top_bun'], p['bottom_bun'] = sorted(buns, key=lambda c: c[2])
    tb, bb = p['top_bun'], p['bottom_bun']
    burger_x0, burger_x1 = min(tb[1], bb[1]) - 40 * UP, max(tb[1] + tb[0].shape[1], bb[1] + bb[0].shape[1]) + 40 * UP
    browns = components(m('brown'), 3000)
    bun_bottom = bb[2] + bb[0].shape[0]
    p['patty'] = max((c for c in browns if c[2] < bun_bottom and c[2] > tb[2]), key=lambda c: c[3])
    p['letters'] = sorted((c for c in browns if c[2] >= bun_bottom - 20 * UP and c[3] > 3000), key=lambda c: c[1])
    seeds = [c for c in components(m('seed'), 400)
             if tb[1] < c[1] < tb[1] + tb[0].shape[1] and tb[2] < c[2] < tb[2] + tb[0].shape[0]]
    p['seeds'] = sorted(sorted(seeds, key=lambda c: -c[3])[:3], key=lambda c: c[1])
    return p


if __name__ == '__main__':
    p = part_masks()
    print('size', W, H, 'disc', [round(v, 1) for v in p['disc']])
    for k, v in p.items():
        if k == 'disc': continue
        for c, x0, y0, n in (v if isinstance(v, list) else [v]):
            print(f'{k:10s} x0={x0:5d} y0={y0:5d} w={c.shape[1]:5d} h={c.shape[0]:5d} px={n}')

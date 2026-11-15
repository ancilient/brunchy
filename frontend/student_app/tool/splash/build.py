"""Builds the Brunchy splash Lottie from the real logo (traced from the round logo image, see parts.py).

Canvas 1080x1080, transparent, 60 fps, 3 s. Timeline:
  0.00-0.43 s  yellow disc pops in
  0.23-0.80 s  burger builds itself: bottom bun and patty drop in, then the top bun lands (squash)
  0.90-1.15 s  seeds pop one by one
  1.30-1.85 s  the bite: anticipation squat, the bite snaps out of the bun, crumbs fly, ripple ring, spring back
  1.80-2.50 s  "Brunchy" letters rise in one by one with a little overshoot
  2.50-3.00 s  hold
"""
import json
import os
import numpy as np
from tracer import contours, rdp_closed, smooth_closed, area, fill_holes_smaller_than
from parts import part_masks, full, colour_of, H, W as IMG_W, UP, m

OUT = os.environ.get('BRUNCHY_SPLASH_OUT') or     os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'splash', 'brunchy_splash.json')
DISC_COLOUR = os.environ.get('BRUNCHY_DISC_COLOUR')   # e.g. '#14C4AE' for the vendor app; default = the logo's yellow
FPS, OP, W = 60, 180, 1080
R = 380                                  # disc radius on the 1080 canvas

P = part_masks()
CX, CY, RPX = P['disc']
S = R / RPX                              # source px -> Lottie units


def rgba(h, a=1):
    h = h.lstrip('#'); return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)] + [a]


def L(x, y):  # source px -> logo-local Lottie units (origin at the disc centre)
    return [round((x - CX) * S, 2), round((y - CY) * S, 2)]


# ---------------- tracing ----------------

def trace_mask(mk, x0, y0, eps=0.6 * UP):
    mk = fill_holes_smaller_than(mk.copy(), 150 * UP * UP)
    loops = []
    for lp in contours(mk):
        if abs(area(lp)) < 120 * UP * UP: continue
        lp = smooth_closed(lp, 4)
        lp = rdp_closed(lp, eps)
        loops.append([L(x + x0, y + y0) for x, y in lp])
    return loops


def path_items(loops):
    return [{'ty': 'sh', 'ks': {'a': 0, 'k': {'i': [[0, 0]] * len(lp), 'o': [[0, 0]] * len(lp), 'v': lp, 'c': True}}} for lp in loops]


def erode(mk):
    return mk & np.roll(mk, 1, 0) & np.roll(mk, -1, 0) & np.roll(mk, 1, 1) & np.roll(mk, -1, 1)


def dilate(mk, n=1):
    for _ in range(n):
        mk = mk | np.roll(mk, 1, 0) | np.roll(mk, -1, 0) | np.roll(mk, 1, 1) | np.roll(mk, -1, 1)
    return mk


def fit_circle(pts):
    x, y = pts[:, 0], pts[:, 1]
    A = np.c_[2 * x, 2 * y, np.ones(len(x))]
    cx, cy, c = np.linalg.lstsq(A, x ** 2 + y ** 2, rcond=None)[0]
    return cx, cy, np.sqrt(c + cx ** 2 + cy ** 2)


def ransac_circles(pts, n, tol=2.5 * UP, iters=4000, seed=1):
    rng = np.random.default_rng(seed)
    found = []
    for _ in range(n):
        if len(pts) < 10: break
        best_in = None
        for _ in range(iters):
            s = pts[rng.choice(len(pts), 3, replace=False)]
            try:
                cx, cy, r = fit_circle(s)
            except Exception:
                continue
            if not np.isfinite(r) or r < 15 * UP or r > 200 * UP: continue
            inl = np.abs(np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) - r) < tol
            if best_in is None or inl.sum() > best_in.sum():
                best_in = inl
        found.append(fit_circle(pts[best_in]))
        pts = pts[~best_in]
    return found


# ---------------- the bite ----------------
# The bun is (nearly) symmetric, so the uneaten top-right corner is the mirror of the top-left one. Only the
# bitten corner is taken from the mirror; everywhere else the real bun outline is kept as it is.
top = full(P['top_bun'])
tb_m, tx0, ty0, _ = P['top_bun']
axis = tx0 + tb_m.shape[1] / 2
xs = np.arange(IMG_W)
src_x = np.clip(np.round(2 * axis - xs).astype(int), 0, IMG_W - 1)
mirror = top[:, src_x]
seeds_any = m('seed')
corner = np.zeros_like(top)
corner[ty0:ty0 + int(tb_m.shape[0] * 0.6), int(axis + tb_m.shape[1] * 0.12):] = True
bite_region = mirror & ~top & ~dilate(seeds_any, 3) & corner
bite_region = fill_holes_smaller_than(bite_region, 200 * UP * UP)
dome = top | bite_region
# Close the little steps where the mirrored patch meets the real outline (only around that corner).
n = 6 * UP
closed = dome
for _ in range(n): closed = dilate(closed)
for _ in range(n): closed = erode(closed)
dome = top | (closed & dilate(corner, n))
dome = fill_holes_smaller_than(dome, 10 ** 8)          # fill the seed holes: seeds are drawn on top
# Bite circles: fitted to the concave (bitten) edge, i.e. the bite region's edge that is inside the mirrored dome.
edge = bite_region & ~erode(bite_region)
mirror_edge = dilate(mirror & ~erode(mirror), 3 * UP)
ys, xs_ = np.nonzero(edge & ~mirror_edge)
bites = sorted(ransac_circles(np.c_[xs_, ys].astype(float), 2), key=lambda c: -c[2])
print('bites (source px):', [(round(a), round(b), round(r)) for a, b, r in bites])

# ---------------- Lottie helpers ----------------
EASE = {
    'out': ({'x': [0.22], 'y': [1]}, {'x': [0.36], 'y': [1]}),
    'inout': ({'x': [0.65], 'y': [0]}, {'x': [0.35], 'y': [1]}),
    'in': ({'x': [0.55], 'y': [0]}, {'x': [0.68], 'y': [0.53]}),
    'lin': ({'x': [0], 'y': [0]}, {'x': [1], 'y': [1]}),
}


def anim(keys, ease='out'):
    """keys: [(frame, value[, ease])]; value scalar or list."""
    ks = []
    for i, k in enumerate(keys):
        f, v = k[0], k[1]
        e = k[2] if len(k) > 2 else ease
        v = v if isinstance(v, list) else [v]
        kf = {'t': f, 's': v}
        if i < len(keys) - 1:
            o, inn = EASE[e]
            n = len(v)
            kf['o'] = {'x': o['x'] * n, 'y': o['y'] * n}
            kf['i'] = {'x': inn['x'] * n, 'y': inn['y'] * n}
        ks.append(kf)
    return {'a': 1, 'k': ks}


def static(v):
    return {'a': 0, 'k': v}


def ks(p=(0, 0), a=(0, 0), s=100, r=0, o=100):
    wrap = lambda v, f: v if isinstance(v, dict) else static(f(v))
    return {
        'o': wrap(o, lambda v: v), 'r': wrap(r, lambda v: v),
        'p': wrap(p, lambda v: [v[0], v[1], 0]), 'a': wrap(a, lambda v: [v[0], v[1], 0]),
        's': wrap(s, lambda v: [v, v, 100] if not isinstance(v, (list, tuple)) else [v[0], v[1], 100]),
    }


TR0 = lambda: {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]), 'r': static(0), 'o': static(100),
               'sk': static(0), 'sa': static(0)}


def group(items, color, rule=1, nm=''):
    return {'ty': 'gr', 'nm': nm, 'it': items + [{'ty': 'fl', 'c': static(rgba(color)), 'o': static(100), 'r': rule}, TR0()]}


layers = []
def layer(nm, shapes, transform, parent=None, ty=4):
    ind = len(layers) + 1
    lyr = {'ddd': 0, 'ind': ind, 'ty': ty, 'nm': nm, 'sr': 1, 'ks': transform, 'ao': 0, 'ip': 0, 'op': OP, 'st': 0, 'bm': 0}
    if ty == 4: lyr['shapes'] = shapes
    if parent: lyr['parent'] = parent
    layers.append(lyr)
    return ind


def pop(f0, dur=12, over=112):
    return anim([(f0, [0, 0]), (f0 + dur * 0.65, [over, over]), (f0 + dur, [100, 100])])


COL = {
    'disc': DISC_COLOUR or colour_of(m('disc')), 'bun': colour_of(top), 'seed': colour_of(seeds_any),
    'patty': colour_of(full(P['patty'])), 'text': colour_of(full(P['letters'][0])),
}
print('colours', COL)

# Null rigs: logo at canvas centre; burger pivots at the base of the bottom bun for squash and tilt.
logo = layer('logo-rig', None, ks(p=(540, 540)), ty=3)
bb_m, _, bby0, _ = P['bottom_bun']
base = L(0, bby0 + bb_m.shape[0])[1]
burger = layer('burger-rig', None, ks(
    p=(0, base), a=(0, base),
    s=anim([(0, [100, 100]), (44, [100, 100]), (48, [104, 93]), (54, [98, 103]), (60, [100, 100]),
            (78, [100, 100]), (84, [104, 95], 'inout'), (90, [97, 104]), (98, [101, 98]), (108, [100, 100])]),
    r=anim([(0, 0), (84, 0), (90, -5), (100, 2.5), (110, 0)]),
), parent=logo, ty=3)

parts = {}

def centre(loops):
    vs = [v for lp in loops for v in lp]
    return round(float(np.mean([v[0] for v in vs])), 2), round(float(np.mean([v[1] for v in vs])), 2)


def drop_layer(nm, loops, color, f0, dy, parent, dur=18):
    cx, cy = centre(loops)
    t = ks(p=anim([(0, [cx, cy - dy]), (f0, [cx, cy - dy]), (f0 + dur * 0.75, [cx, cy + 4]), (f0 + dur, [cx, cy])]),
           a=(cx, cy), o=anim([(0, 0), (f0, 0), (f0 + 6, 100)], 'lin'))
    parts[nm] = (nm, [group(path_items(loops), color, 1, nm)], t, parent)

drop_layer('bottom-bun', trace_mask(*P['bottom_bun'][:3]), COL['bun'], 14, 240, burger)
drop_layer('patty', trace_mask(*P['patty'][:3]), COL['patty'], 22, 270, burger)
ys_, xs2 = np.nonzero(dome)
y0d, x0d = ys_.min(), xs2.min()
drop_layer('top-bun', trace_mask(dome[y0d:ys_.max() + 1, x0d:xs2.max() + 1], x0d, y0d), COL['bun'], 30, 320, burger, dur=16)

bite_shapes = []
for i, (bx, by, br) in enumerate(bites):
    c = L(bx, by); d = round(2 * br * S, 2)
    f0 = 84 + i * 3
    bite_shapes.append({'ty': 'gr', 'nm': f'bite{i + 1}', 'it': [
        {'ty': 'el', 'p': static(c), 's': static([d, d])},
        {'ty': 'fl', 'c': static(rgba(COL['disc'])), 'o': static(100), 'r': 1},
        {'ty': 'tr', 'p': static(c), 'a': static(c), 's': anim([(0, [0, 0]), (f0, [0, 0]), (f0 + 5, [108, 108]), (f0 + 9, [100, 100])]),
         'r': static(0), 'o': static(100), 'sk': static(0), 'sa': static(0)},
    ]})
parts['bites'] = ('bites', bite_shapes, ks(), burger)

for i, sc in enumerate(P['seeds']):
    mk, x0, y0, _ = sc
    cx, cy = L(x0 + mk.shape[1] / 2, y0 + mk.shape[0] / 2)
    parts[f'seed{i + 1}'] = (f'seed-{i + 1}', [group(path_items(trace_mask(*sc[:3])), COL['seed'], 1)],
                             ks(p=(cx, cy), a=(cx, cy), s=pop(54 + i * 4, 10, 125)), burger)

# Crumbs fly off the bite and fall.
bx, by, br = bites[0]
origin = L(bx, by + br * 0.3)
crumbs = []
for i, (vx, vy, size, delay) in enumerate([(70, -60, 16, 0), (110, -10, 12, 1), (45, -95, 10, 2), (95, -80, 9, 3), (130, 20, 8, 1)]):
    f0 = 85 + delay
    p0 = origin
    mid = [round(p0[0] + vx * 0.7, 2), round(p0[1] + vy * 0.7, 2)]
    end = [round(p0[0] + vx, 2), round(p0[1] + vy + 90, 2)]
    crumbs.append({'ty': 'gr', 'nm': f'crumb{i}', 'it': [
        {'ty': 'el', 'p': static([0, 0]), 's': static([size, size])},
        {'ty': 'fl', 'c': static(rgba(COL['bun'])), 'o': static(100), 'r': 1},
        {'ty': 'tr', 'p': anim([(0, p0), (f0, p0), (f0 + 10, mid), (f0 + 30, end, 'in')]), 'a': static([0, 0]),
         's': static([100, 100]), 'r': static(0), 'o': anim([(0, 0), (f0, 0), (f0 + 1, 100), (f0 + 20, 100), (f0 + 30, 0)], 'lin'),
         'sk': static(0), 'sa': static(0)},
    ]})
parts['crumbs'] = ('crumbs', crumbs, ks(), logo)

letters = []
for i, lc in enumerate(P['letters']):
    mk, x0, y0, _ = lc
    cx, cy = L(x0 + mk.shape[1] / 2, y0 + mk.shape[0])  # pivot at the letter's foot
    f0 = 108 + i * 5
    letters.append((f'letter-{i + 1}', [group(path_items(trace_mask(*lc[:3])), COL['text'], 2)],
                    ks(p=anim([(0, [cx, cy + 46]), (f0, [cx, cy + 46]), (f0 + 11, [cx, cy - 5]), (f0 + 17, [cx, cy])]), a=(cx, cy),
                       s=anim([(0, [60, 60]), (f0, [60, 60]), (f0 + 11, [106, 106]), (f0 + 17, [100, 100])]),
                       o=anim([(0, 0), (f0, 0), (f0 + 7, 100)], 'lin')), logo))

disc = ('disc', [{'ty': 'gr', 'nm': 'disc', 'it': [
    {'ty': 'el', 'p': static([0, 0]), 's': static([2 * R, 2 * R])},
    {'ty': 'fl', 'c': static(rgba(COL['disc'])), 'o': static(100), 'r': 1}, TR0(),
]}], ks(s=anim([(0, [0, 0]), (18, [106, 106]), (26, [100, 100])]), o=anim([(0, 0), (8, 100)], 'lin')), logo)

ripple = ('ripple', [{'ty': 'gr', 'nm': 'ring', 'it': [
    {'ty': 'el', 'p': static([0, 0]), 's': anim([(0, [2 * R, 2 * R]), (84, [2 * R, 2 * R]), (124, [2 * R + 260, 2 * R + 260])])},
    {'ty': 'st', 'c': static(rgba(COL['disc'])), 'o': anim([(0, 0), (84, 0), (86, 90), (124, 0)], 'out'),
     'w': anim([(84, 18), (124, 3)]), 'lc': 2, 'lj': 2}, TR0(),
]}], ks(), logo)

# Lottie draws the first layer on top. (The two rigs are null layers: they never draw.)
order = letters + [parts[k] for k in ['crumbs', 'patty', 'bottom-bun', 'seed3', 'seed2', 'seed1', 'bites', 'top-bun']] + [disc, ripple]
for nm, shapes, t, parent in order:
    layer(nm, shapes, t, parent)

doc = {'v': '5.7.4', 'fr': FPS, 'ip': 0, 'op': OP, 'w': W, 'h': W, 'nm': 'Brunchy splash', 'ddd': 0, 'assets': [], 'layers': layers}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w') as f:
    json.dump(doc, f, separators=(',', ':'))
print('wrote', os.path.normpath(OUT), os.path.getsize(OUT) // 1024, 'KB', 'layers', len(layers))

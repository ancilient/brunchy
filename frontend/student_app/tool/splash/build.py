"""Builds the Brunchy splash Lottie from the real logo (traced from the 4096 px master).

Canvas 1080x1080, transparent, 60 fps, 3 s. Timeline:
  0.00-0.43 s  yellow disc pops in
  0.23-0.87 s  burger builds itself: bottom bun, patty, cheese drop in, then the top bun lands (squash)
  0.90-1.20 s  seeds pop one by one, the smile widens
  1.30-1.85 s  the bite: anticipation squat, bite circles snap out of the bun, crumbs fly, ripple ring, spring back
  1.80-2.50 s  "Brunchy" letters rise in one by one with a little overshoot
  2.50-3.00 s  hold
"""
import json
import os
import numpy as np
from tracer import components, contours, rdp_closed, smooth_closed, area, fill_holes_smaller_than
from parts import part_masks, label, NAMES

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'splash', 'brunchy_splash.json')
FPS, OP, W = 60, 180, 1080
C0 = 2048.0                       # logo centre in master px
S = 380.0 / 1536.0                # master px -> Lottie units (disc radius 1536 px -> 380)
COL = {'disc': '#FFD440', 'bun': '#F97619', 'patty': '#491E0B', 'brown': '#58280F', 'cheese': '#FFD84D', 'seed': '#FFE698'}


def rgba(h, a=1):
    h = h.lstrip('#'); return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)] + [a]


def L(x, y):  # master px -> logo-local Lottie units
    return [round((x - C0) * S, 2), round((y - C0) * S, 2)]


# ---------------- tracing ----------------

def trace_mask(m, x0, y0, eps=1.5):
    m = fill_holes_smaller_than(m.copy(), 400)
    loops = []
    for lp in contours(m):
        if abs(area(lp)) < 300: continue
        lp = smooth_closed(lp, 3)
        lp = rdp_closed(lp, eps)
        loops.append([L(x + x0, y + y0) for x, y in lp])
    return loops


def path_items(loops):
    return [{'ty': 'sh', 'ks': {'a': 0, 'k': {'i': [[0, 0]] * len(lp), 'o': [[0, 0]] * len(lp), 'v': lp, 'c': True}}} for lp in loops]


def erode(m):
    return m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)


def fit_circle(pts):
    x, y = pts[:, 0], pts[:, 1]
    A = np.c_[2 * x, 2 * y, np.ones(len(x))]
    b = x ** 2 + y ** 2
    cx, cy, c = np.linalg.lstsq(A, b, rcond=None)[0]
    return cx, cy, np.sqrt(c + cx ** 2 + cy ** 2)


def ransac_circles(pts, n, tol=3.0, iters=3000, seed=1):
    rng = np.random.default_rng(seed)
    found = []
    pts = pts.copy()
    for _ in range(n):
        best, best_in = None, None
        for _ in range(iters):
            s = pts[rng.choice(len(pts), 3, replace=False)]
            try:
                cx, cy, r = fit_circle(s)
            except Exception:
                continue
            if not np.isfinite(r) or r < 40 or r > 800: continue
            inl = np.abs(np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) - r) < tol
            if best_in is None or inl.sum() > best_in.sum():
                best, best_in = (cx, cy, r), inl
        found.append(fit_circle(pts[best_in]))
        pts = pts[~best_in]
    return found


# ---------------- logo geometry ----------------

P = part_masks()
H = label.shape[0]
full = lambda c: (lambda m, x0, y0: (np.pad(m, ((y0, H - y0 - m.shape[0]), (x0, H - x0 - m.shape[1])))))(c[0], c[1], c[2])

top = full(P['top_bun'])
# Uneaten dome: the bun is symmetric about x = 2048, so mirror the (unbitten) left half over the bite; fill seed/smile holes.
dome = top | top[:, ::-1]
dome = fill_holes_smaller_than(dome, 10 ** 7)
seeds_m = label == NAMES.index('seed')
smile_m = full(P['smile'])
bite_region = dome & ~top & ~seeds_m & ~smile_m
bite_region = fill_holes_smaller_than(bite_region, 400)
edge = bite_region & ~erode(bite_region)
near_dome_edge = dome & ~erode(erode(erode(erode(dome))))
for _ in range(3): near_dome_edge = near_dome_edge | np.roll(near_dome_edge, 1, 0) | np.roll(near_dome_edge, 1, 1) | np.roll(near_dome_edge, -1, 0) | np.roll(near_dome_edge, -1, 1)
ys, xs = np.nonzero(edge & ~near_dome_edge)
bites = sorted(ransac_circles(np.c_[xs, ys].astype(float), 2), key=lambda c: -c[2])
print('bites (master px):', [(round(a), round(b), round(r)) for a, b, r in bites])

def bbox_centre(c):
    m, x0, y0, _ = c
    return x0 + m.shape[1] / 2, y0 + m.shape[0] / 2


# ---------------- Lottie helpers ----------------
EASE = {
    'out': ({'x': [0.22], 'y': [1]}, {'x': [0.36], 'y': [1]}),
    'inout': ({'x': [0.65], 'y': [0]}, {'x': [0.35], 'y': [1]}),
    'in': ({'x': [0.55], 'y': [0]}, {'x': [0.68], 'y': [0.53]}),
    'lin': ({'x': [0], 'y': [0]}, {'x': [1], 'y': [1]}),
}


def anim(keys, ease='out'):
    """keys: [(frame, value)]; value scalar or list. Same easing on every segment unless (frame, value, ease)."""
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


def group(items, color, rule=1, nm=''):
    return {'ty': 'gr', 'nm': nm, 'it': items + [
        {'ty': 'fl', 'c': static(rgba(color)), 'o': static(100), 'r': rule},
        {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]), 'r': static(0), 'o': static(100),
         'sk': static(0), 'sa': static(0)},
    ]}


layers = []
def layer(nm, shapes, transform, parent=None, ty=4):
    ind = len(layers) + 1
    lyr = {'ddd': 0, 'ind': ind, 'ty': ty, 'nm': nm, 'sr': 1, 'ks': transform, 'ao': 0, 'ip': 0, 'op': OP, 'st': 0, 'bm': 0}
    if ty == 4: lyr['shapes'] = shapes
    if parent: lyr['parent'] = parent
    layers.append(lyr)
    return ind


def pop(f0, dur=12, over=112, frm=0):
    """Scale keys 0 -> overshoot -> 100."""
    return anim([(f0, [frm, frm]), (f0 + dur * 0.65, [over, over]), (f0 + dur, [100, 100])])


# Null rigs. Logo rig at canvas centre; burger rig pivots at the base of the bottom bun for squash and tilt.
logo = layer('logo-rig', None, ks(p=(540, 540)), ty=3)
base = round((2512 - C0) * S, 2)  # bottom of the bottom bun (local y)
burger = layer('burger-rig', None, ks(
    p=(0, base), a=(0, base),
    s=anim([(0, [100, 100]), (46, [100, 100]), (50, [104, 93]), (56, [98, 103]), (62, [100, 100]),
            (78, [100, 100]), (84, [104, 95], 'inout'), (90, [97, 104]), (98, [101, 98]), (108, [100, 100])]),
    r=anim([(0, 0), (84, 0), (90, -5), (100, 2.5), (110, 0)]),
), parent=logo, ty=3)

# ---- burger parts (z-order is set by layer order at the end; build them into a dict first)
parts = {}

def drop_layer(nm, loops, color, f0, dy, parent, rule=1, dur=18):
    cx = round(np.mean([v[0] for lp in loops for v in lp]), 2); cy = round(np.mean([v[1] for lp in loops for v in lp]), 2)
    t = ks(p=anim([(0, [cx, cy - dy]), (f0, [cx, cy - dy]), (f0 + dur * 0.75, [cx, cy + 4]), (f0 + dur, [cx, cy])]),
           a=(cx, cy), o=anim([(0, 0), (f0, 0), (f0 + 6, 100)], 'lin'))
    parts[nm] = ('layer', nm, [group(path_items(loops), color, rule, nm)], t, parent)

drop_layer('bottom-bun', trace_mask(*P['bottom_bun'][:3]), COL['bun'], 14, 240, burger)
drop_layer('patty', trace_mask(*P['patty'][:3]), COL['patty'], 20, 260, burger)
drop_layer('cheese', trace_mask(*P['cheese'][:3]), COL['cheese'], 26, 280, burger)

# Top bun lands last with the uneaten dome; the bite circles cut it later.
dm, dx0, dy0 = dome[900:1900], 0, 900
drop_layer('top-bun', trace_mask(dm, dx0, dy0), COL['bun'], 32, 320, burger, dur=16)

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
parts['bites'] = ('layer', 'bites', bite_shapes, ks(), burger)

for i, sc in enumerate(P['seeds']):
    loops = trace_mask(*sc[:3])
    cx, cy = L(*bbox_centre(sc))
    parts[f'seed{i + 1}'] = ('layer', f'seed-{i + 1}', [group(path_items(loops), COL['seed'], 1)],
                             ks(p=(cx, cy), a=(cx, cy), s=pop(54 + i * 4, 10, 125)), burger)

sm = P['smile']
cx, cy = L(*bbox_centre(sm))
parts['smile'] = ('layer', 'smile', [group(path_items(trace_mask(*sm[:3])), COL['brown'], 1)],
                  ks(p=(cx, cy), a=(cx, cy), s=anim([(0, [0, 100]), (62, [0, 100]), (70, [112, 100]), (76, [100, 100])])), burger)

# Crumbs fly off the bite and fall.
bx, by, br = bites[0]
origin = L(bx - br * 0.2, by + br * 0.1)
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
parts['crumbs'] = ('layer', 'crumbs', crumbs, ks(), logo)

# ---- letters rise in one by one
letters = []
for i, lc in enumerate(P['letters']):
    loops = trace_mask(*lc[:3])
    m_, x0, y0, _ = lc
    cx, cy = L(x0 + m_.shape[1] / 2, y0 + m_.shape[0])  # pivot at the letter's foot
    f0 = 108 + i * 5
    letters.append(('layer', f'letter-{i + 1}', [group(path_items(loops), COL['brown'], 2)],
                    ks(p=anim([(0, [cx, cy + 46]), (f0, [cx, cy + 46]), (f0 + 11, [cx, cy - 5]), (f0 + 17, [cx, cy])]), a=(cx, cy),
                       s=anim([(0, [60, 60]), (f0, [60, 60]), (f0 + 11, [106, 106]), (f0 + 17, [100, 100])]),
                       o=anim([(0, 0), (f0, 0), (f0 + 7, 100)], 'lin')), logo))

# ---- disc and ripple
R = 380
disc = ('layer', 'disc', [{'ty': 'gr', 'nm': 'disc', 'it': [
    {'ty': 'el', 'p': static([0, 0]), 's': static([2 * R, 2 * R])},
    {'ty': 'fl', 'c': static(rgba(COL['disc'])), 'o': static(100), 'r': 1},
    {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]), 'r': static(0), 'o': static(100), 'sk': static(0), 'sa': static(0)},
]}], ks(s=anim([(0, [0, 0]), (18, [106, 106]), (26, [100, 100])]), o=anim([(0, 0), (8, 100)], 'lin')), logo)

ripple = ('layer', 'ripple', [{'ty': 'gr', 'nm': 'ring', 'it': [
    {'ty': 'el', 'p': static([0, 0]), 's': anim([(0, [2 * R, 2 * R]), (84, [2 * R, 2 * R]), (124, [2 * R + 260, 2 * R + 260])])},
    {'ty': 'st', 'c': static(rgba(COL['disc'])), 'o': anim([(0, 0), (84, 0), (86, 90), (124, 0)], 'out'),
     'w': anim([(84, 18), (124, 3)]), 'lc': 2, 'lj': 2},
    {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]), 'r': static(0), 'o': static(100), 'sk': static(0), 'sa': static(0)},
]}], ks(), logo)

# ---- assemble: Lottie draws the first layer on top
order = letters + [parts[k] for k in ['crumbs', 'patty', 'cheese', 'bottom-bun', 'smile', 'seed3', 'seed2', 'seed1', 'bites', 'top-bun']] + [disc, ripple]
for _, nm, shapes, t, parent in order:
    layer(nm, shapes, t, parent)
# (the two rigs are null layers: they never draw, so their position in the list does not matter)

doc = {'v': '5.7.4', 'fr': FPS, 'ip': 0, 'op': OP, 'w': W, 'h': W, 'nm': 'Brunchy splash', 'ddd': 0, 'assets': [], 'layers': layers}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w') as f:
    json.dump(doc, f, separators=(',', ':'))
print('wrote', OUT, os.path.getsize(OUT) // 1024, 'KB', 'layers', len(layers))

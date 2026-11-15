"""Tiny raster tracer: connected components + pixel-edge contour tracing + Douglas-Peucker simplification."""
import numpy as np


def components(mask, min_px=200):
    """4-connected components via run-length union-find. Returns list of boolean masks (bbox-cropped) with offsets."""
    H, W = mask.shape
    runs = []  # (y, x0, x1)
    row_runs = []
    for y in range(H):
        r = mask[y]
        if not r.any():
            row_runs.append([]); continue
        d = np.diff(np.concatenate(([0], r.view(np.int8), [0])))
        s, e = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
        ids = []
        for a, b in zip(s, e):
            ids.append(len(runs)); runs.append((y, a, b))
        row_runs.append(ids)
    parent = list(range(len(runs)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i

    for y in range(1, H):
        prev, cur = row_runs[y - 1], row_runs[y]
        i = j = 0
        while i < len(prev) and j < len(cur):
            _, a0, a1 = runs[prev[i]]; _, b0, b1 = runs[cur[j]]
            if a0 < b1 and b0 < a1:
                ra, rb = find(prev[i]), find(cur[j])
                if ra != rb: parent[ra] = rb
            if a1 < b1: i += 1
            else: j += 1
    groups = {}
    for k, (y, a, b) in enumerate(runs):
        groups.setdefault(find(k), []).append((y, a, b))
    out = []
    for g in groups.values():
        n = sum(b - a for _, a, b in g)
        if n < min_px: continue
        ys = [y for y, _, _ in g]; x0 = min(a for _, a, _ in g); x1 = max(b for _, _, b in g)
        y0, y1 = min(ys), max(ys) + 1
        m = np.zeros((y1 - y0, x1 - x0), bool)
        for y, a, b in g: m[y - y0, a - x0:b - x0] = True
        out.append((m, x0, y0, n))
    return out


def fill_holes_smaller_than(m, max_px):
    """Fill background components fully enclosed by m that are smaller than max_px (anti-alias specks)."""
    inv = ~m
    for c, x0, y0, n in components(inv, min_px=0):
        h, w = c.shape
        touches = x0 == 0 or y0 == 0 or x0 + w == m.shape[1] or y0 + h == m.shape[0]
        if not touches and n < max_px:
            m[y0:y0 + h, x0:x0 + w] |= c
    return m


def contours(m):
    """Closed loops along pixel edges, foreground on the right (y down). Diagonal touches are split (4-connected)."""
    p = np.pad(m, 1)
    fg = p[1:-1, 1:-1]
    H, W = fg.shape
    ys, xs = np.nonzero(fg & ~p[:-2, 1:-1])
    edges = [((x, y), (x + 1, y)) for x, y in zip(xs, ys)]                      # top
    ys, xs = np.nonzero(fg & ~p[1:-1, 2:])
    edges += [((x + 1, y), (x + 1, y + 1)) for x, y in zip(xs, ys)]             # right
    ys, xs = np.nonzero(fg & ~p[2:, 1:-1])
    edges += [((x + 1, y + 1), (x, y + 1)) for x, y in zip(xs, ys)]             # bottom
    ys, xs = np.nonzero(fg & ~p[1:-1, :-2])
    edges += [((x, y + 1), (x, y)) for x, y in zip(xs, ys)]                     # left
    out = {}
    for a, b in edges:
        out.setdefault((int(a[0]), int(a[1])), []).append((int(b[0]), int(b[1])))
    loops = []
    while out:
        start = next(iter(out))
        loop = [start]
        cur, prev_dir = start, None
        while True:
            nxts = out[cur]
            if len(nxts) == 1 or prev_dir is None:
                nxt = nxts[0]
            else:  # junction: take the right turn to keep components 4-connected
                def turn(n):
                    d = (n[0] - cur[0], n[1] - cur[1])
                    return prev_dir[0] * d[1] - prev_dir[1] * d[0]  # >0 = right turn (y down)
                nxt = max(nxts, key=turn)
            nxts.remove(nxt)
            if not nxts: del out[cur]
            prev_dir = (nxt[0] - cur[0], nxt[1] - cur[1])
            cur = nxt
            if cur == start: break
            loop.append(cur)
        loops.append(np.array(loop, float))
    return loops


def rdp_closed(pts, eps):
    """Douglas-Peucker on a closed polygon (split at the two farthest points)."""
    i0 = 0
    i1 = int(np.argmax(((pts - pts[0]) ** 2).sum(1)))
    a = _rdp(np.vstack([pts[i0:i1 + 1]]), eps)
    b = _rdp(np.vstack([pts[i1:], pts[:1]]), eps)
    return np.vstack([a[:-1], b[:-1]])


def _rdp(pts, eps):
    keep = np.zeros(len(pts), bool); keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        s, e = stack.pop()
        if e <= s + 1: continue
        a, b = pts[s], pts[e]
        seg = b - a
        L = np.hypot(*seg)
        q = pts[s + 1:e] - a
        dist = np.abs(seg[0] * q[:, 1] - seg[1] * q[:, 0]) / L if L > 0 else np.hypot(q[:, 0], q[:, 1])
        k = int(np.argmax(dist))
        if dist[k] > eps:
            m = s + 1 + k; keep[m] = True
            stack += [(s, m), (m, e)]
    return pts[keep]


def smooth_closed(pts, passes=2):
    """Light Chaikin-free smoothing: average with neighbours (keeps shape, removes stair-step wobble)."""
    for _ in range(passes):
        pts = (np.roll(pts, 1, 0) + 2 * pts + np.roll(pts, -1, 0)) / 4
    return pts


def area(pts):
    x, y = pts[:, 0], pts[:, 1]
    return 0.5 * (np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))

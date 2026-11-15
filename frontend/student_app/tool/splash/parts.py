"""Splits the master logo into named part masks (4096 px space)."""
import os
import numpy as np
from PIL import Image
from tracer import components

# The 4096 px master logo (flat colours). Override with BRUNCHY_LOGO=/path/to/brunchy-icon-4096.png
MASTER = os.environ.get('BRUNCHY_LOGO', r'D:/Brunchy/app icon/master/brunchy-icon-4096.png')
PALETTE = {'circle': (255, 212, 64), 'bun': (249, 118, 25), 'patty': (73, 30, 11), 'text': (88, 40, 15),
           'cheese': (255, 216, 77), 'seed': (255, 230, 152)}
NAMES = list(PALETTE)


def _labels():
    """Each opaque pixel -> index of the nearest logo colour (-1 = transparent)."""
    im = np.array(Image.open(MASTER).convert('RGBA')).astype(np.int32)
    cols = np.array([PALETTE[n] for n in NAMES])
    d = ((im[..., :3][:, :, None, :] - cols[None, None]) ** 2).sum(-1)
    return np.where(im[..., 3] > 127, d.argmin(-1), -1).astype(np.int8)


label = _labels()


def m(name):
    return label == NAMES.index(name)


def window(mask, y0, y1):
    out = np.zeros_like(mask); out[y0:y1] = mask[y0:y1]; return out


def biggest(mask, k=1, min_px=2000):
    cs = sorted(components(mask, min_px), key=lambda c: -c[3])
    return cs[:k]


def part_masks():
    H = label.shape[0]
    parts = {}
    parts['top_bun'] = biggest(window(m('bun'), 900, 1900))[0]
    parts['bottom_bun'] = biggest(window(m('bun'), 2150, 2530))[0]
    parts['patty'] = biggest(m('patty'))[0]
    parts['cheese'] = biggest(m('cheese'))[0]
    parts['smile'] = biggest(window(m('text'), 1500, 1850))[0]
    parts['seeds'] = sorted(biggest(m('seed'), k=3, min_px=500), key=lambda c: c[1])
    letters = components(window(m('text'), 2500, 3100), 3000)
    parts['letters'] = sorted(letters, key=lambda c: c[1])
    return parts


if __name__ == '__main__':
    p = part_masks()
    for k, v in p.items():
        vs = v if isinstance(v, list) else [v]
        for c, x0, y0, n in vs:
            print(f'{k:10s} x0={x0:5d} y0={y0:5d} w={c.shape[1]:5d} h={c.shape[0]:5d} px={n}')

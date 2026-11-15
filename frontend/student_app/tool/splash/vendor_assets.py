"""Renders the vendor app's logo images from the teal splash Lottie's final frame (same vector as the animation).

Run after building the teal splash (see README): writes vendor_app/assets/brand/logo.png, brand/burger.png and app-icon.png.
Then in vendor_app: dart run flutter_launcher_icons
"""
import json, os, subprocess, copy
import numpy as np
from PIL import Image
from lottie import objects
from lottie.exporters.svg import export_svg

import tempfile
APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'vendor_app', 'assets') + os.sep
SRC = APP + 'splash/brunchy_vendor_splash.json'
TMP = os.path.join(tempfile.gettempdir(), 'brunchy_vendor_render') + os.sep
CHROME = r'C:/Program Files/Google/Chrome/Application/chrome.exe'
TEAL = '#14C4AE'
os.makedirs(TMP, exist_ok=True)
doc = json.load(open(SRC))


def render(d, name, bg='transparent', size=1080, scale=2):
    svg = TMP + name + '.svg'
    with open(svg, 'w') as fh:
        export_svg(objects.Animation.load(d), fh, frame=179)
    px = size * scale
    html = TMP + name + '.html'
    open(html, 'w').write(f'<html><body style="margin:0;background:{bg}"><img src="{name}.svg" width="{px}" height="{px}"></body></html>')
    png = TMP + name + '.png'
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--default-background-color=00000000',
                    f'--window-size={px},{px}', f'--screenshot={png}', 'file:///' + html], capture_output=True)
    return Image.open(png).convert('RGBA')


# 1) logo disc, transparent outside (rendered at 2x then reduced: smooth edges)
full = render(doc, 'full')
k = full.width / 1080
disc = full.crop((round(160 * k), round(160 * k), round(920 * k), round(920 * k)))
disc.resize((288, 288), Image.LANCZOS).save(APP + 'brand/logo.png', optimize=True)

# 2) full-bleed launcher icon: same art on a teal square, framed like the student icon (content ~65% of the width)
sq = render(doc, 'square', bg=TEAL)
a = np.asarray(full)
yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
inside = (a[..., 3] == 255) & (np.hypot(xx - a.shape[1] / 2, yy - a.shape[0] / 2) < 0.9 * 380 * k)   # skip the disc's rim
teal = np.array([int(TEAL[i:i + 2], 16) for i in (1, 3, 5)])
content = inside & (np.abs(a[..., :3].astype(int) - teal).sum(-1) > 60)
ys, xs = np.nonzero(content)
cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
side = (xs.max() - xs.min()) / 0.65
box = (round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))
pad = Image.new('RGB', (box[2] - box[0], box[3] - box[1]), tuple(int(v) for v in teal))   # teal extends past the render
pad.paste(sq.convert('RGB'), (-box[0], -box[1]))
pad.resize((1024, 1024), Image.LANCZOS).save(APP + 'app-icon.png', optimize=True)
print('icon crop', box)

# 3) burger only (no disc, no letters, no ripple/crumbs) for menu items without a photo
b = copy.deepcopy(doc)
b['layers'] = [l for l in b['layers'] if not (l['nm'].startswith('letter') or l['nm'] in ('disc', 'ripple', 'crumbs', 'bites'))]
# Off the disc the cheese pocket (normally the disc's yellow showing through) would be empty: fill it with cheese.
def verts(nm):
    lyr = next(l for l in b['layers'] if l['nm'] == nm)
    return np.array([v for g in lyr['shapes'] for it in g['it'] if it['ty'] == 'sh' for v in it['ks']['k']['v']])
pv, tv = verts('patty'), verts('top-bun')
x0, x1 = pv[:, 0].min(), pv[:, 0].max()
y0, y1 = tv[:, 1].max() - 6, pv[:, 1].min() + 0.8 * (pv[:, 1].max() - pv[:, 1].min())  # down into the patty, hidden behind it
inset = (x1 - x0) * 0.04
cheese = {'ddd': 0, 'ind': 999, 'ty': 4, 'nm': 'cheese', 'sr': 1, 'ao': 0, 'ip': 0, 'op': b['op'], 'st': 0, 'bm': 0,
          'ks': {'o': {'a': 0, 'k': 100}, 'r': {'a': 0, 'k': 0}, 'p': {'a': 0, 'k': [540, 540, 0]}, 'a': {'a': 0, 'k': [0, 0, 0]}, 's': {'a': 0, 'k': [100, 100, 100]}},
          'shapes': [{'ty': 'gr', 'it': [
              {'ty': 'rc', 'p': {'a': 0, 'k': [(x0 + x1) / 2, (y0 + y1) / 2]}, 's': {'a': 0, 'k': [x1 - x0 - 2 * inset, y1 - y0]}, 'r': {'a': 0, 'k': 0}},
              {'ty': 'fl', 'c': {'a': 0, 'k': [0.984, 0.839, 0.259, 1]}, 'o': {'a': 0, 'k': 100}, 'r': 1},
              {'ty': 'tr', 'p': {'a': 0, 'k': [0, 0]}, 'a': {'a': 0, 'k': [0, 0]}, 's': {'a': 0, 'k': [100, 100]}, 'r': {'a': 0, 'k': 0}, 'o': {'a': 0, 'k': 100}}]}]}
idx = next(i for i, l in enumerate(b['layers']) if l['nm'] == 'top-bun')
b['layers'].insert(idx + 1, cheese)   # below the top bun and patty
burger = render(b, 'burger')
burger = burger.crop(burger.getbbox())
w, h = burger.size
s = max(w, h)
out = Image.new('RGBA', (s, s), (0, 0, 0, 0)); out.alpha_composite(burger, ((s - w) // 2, (s - h) // 2))
out.resize((192, 192), Image.LANCZOS).save(APP + 'brand/burger.png', optimize=True)

# preview strip
strip = Image.new('RGBA', (3 * 300 + 40, 300), (240, 240, 240, 255))
for i, p in enumerate(['brand/logo.png', 'app-icon.png', 'brand/burger.png']):
    strip.alpha_composite(Image.open(APP + p).convert('RGBA').resize((280, 280)), (10 + i * 310, 10))
strip.save(TMP + 'strip.png')

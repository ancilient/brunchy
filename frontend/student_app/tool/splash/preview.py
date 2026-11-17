"""Renders Lottie frames (python-lottie SVG export -> headless Chrome) into a contact sheet, plus an accuracy diff."""
import json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
from lottie import objects
from lottie.exporters.svg import export_svg

import tempfile
D = os.path.join(tempfile.gettempdir(), 'brunchy_splash_preview') + os.sep  # frames, sheet.png, accuracy.png
_HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get('BRUNCHY_SPLASH_OUT') or (
    os.path.join(_HERE, '..', '..', '..', 'vendor_app', 'assets', 'splash', 'brunchy_vendor_splash.json')
    if os.environ.get('BRUNCHY_PROFILE') == 'vendor' else os.path.join(_HERE, '..', '..', 'assets', 'splash', 'brunchy_splash.json'))
CHROME = r'C:/Program Files/Google/Chrome/Application/chrome.exe'
frames = [int(f) for f in sys.argv[1:]]

an = objects.Animation.load(json.load(open(SRC)))
last = int(an.out_point) - 1
frames = frames or [8, 24, 40, 52, 64, 80, 88, 96, 116, 140, 160, last]   # ends on the final frame
os.makedirs(D + 'frames', exist_ok=True)
print('preview ->', D)
shots = []
for f in frames:
    svg = D + f'frames/f{f}.svg'
    with open(svg, 'w') as fh:
        export_svg(an, fh, frame=f)
    html = D + f'frames/f{f}.html'
    open(html, 'w').write(f'<html><body style="margin:0;background:#FAF2E4"><img src="f{f}.svg" width="1080" height="1080"></body></html>')
    png = D + f'frames/f{f}.png'
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--window-size=1080,1080',
                    f'--screenshot={png}', 'file:///' + html], capture_output=True)
    shots.append(png)

cell = 270
sheet = Image.new('RGB', (cell * 4, cell * ((len(shots) + 3) // 4) + 0), 'white')
for i, (f, p) in enumerate(zip(frames, shots)):
    im = Image.open(p).convert('RGB').resize((cell, cell))
    ImageDraw.Draw(im).text((6, 4), f'f{f} ({f / 60:.2f}s)', fill=(90, 90, 90))
    sheet.paste(im, ((i % 4) * cell, (i // 4) * cell))
sheet.save(D + 'sheet.png')

# accuracy: last frame vs the real logo, scaled and placed so its disc matches the animation's disc
from parts import fit_disc, UP, SRC as LOGO
last = Image.open(shots[-1]).convert('RGB')
cx, cy, r = [v / UP for v in fit_disc()]
k = 380 / r
logo = Image.open(LOGO).convert('RGB')
logo = logo.resize((round(logo.width * k), round(logo.height * k)), Image.LANCZOS)
ref = Image.new('RGB', (1080, 1080), (250, 242, 228))
mask = Image.new('L', logo.size, 0)
ImageDraw.Draw(mask).ellipse((cx * k - 380, cy * k - 380, cx * k + 380, cy * k + 380), fill=255)
ref.paste(logo, (round(540 - cx * k), round(540 - cy * k)), mask)
ref = ref.convert('RGB')
a, b = np.asarray(last, float), np.asarray(ref, float)
diff = np.abs(a - b).sum(-1)
print('mean abs diff', round(diff.mean(), 2), 'pixels off by >60:', int((diff > 60).sum()), 'of', diff.size)
vis = Image.fromarray(np.clip(diff * 2, 0, 255).astype(np.uint8))
side = Image.new('RGB', (1080 * 3 // 2, 540), 'white')
side.paste(ref.resize((540, 540)), (0, 0)); side.paste(last.resize((540, 540)), (540, 0)); side.paste(vis.convert('RGB').resize((540, 540)), (1080, 0))
side.save(D + 'accuracy.png')

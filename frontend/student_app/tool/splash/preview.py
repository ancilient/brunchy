"""Renders Lottie frames (python-lottie SVG export -> headless Chrome) into a contact sheet, plus an accuracy diff."""
import json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw
from lottie import objects
from lottie.exporters.svg import export_svg

import tempfile
D = os.path.join(tempfile.gettempdir(), 'brunchy_splash_preview') + os.sep  # frames, sheet.png, accuracy.png
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'splash', 'brunchy_splash.json')
CHROME = r'C:/Program Files/Google/Chrome/Application/chrome.exe'
frames = [int(f) for f in sys.argv[1:]] or [8, 24, 40, 52, 64, 80, 88, 96, 116, 130, 150, 179]

an = objects.Animation.load(json.load(open(SRC)))
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

# accuracy: last frame vs the master logo placed at the same scale
last = Image.open(shots[-1]).convert('RGB')
S = 380 / 1536
logo = Image.open(os.environ.get('BRUNCHY_LOGO', r'D:/Brunchy/app icon/master/brunchy-icon-4096.png')).convert('RGBA').resize((round(4096 * S),) * 2, Image.LANCZOS)
ref = Image.new('RGBA', (1080, 1080), (250, 242, 228, 255))
off = round(540 - 2048 * S)
ref.alpha_composite(logo, (off, off))
ref = ref.convert('RGB')
a, b = np.asarray(last, float), np.asarray(ref, float)
diff = np.abs(a - b).sum(-1)
print('mean abs diff', round(diff.mean(), 2), 'pixels off by >60:', int((diff > 60).sum()), 'of', diff.size)
vis = Image.fromarray(np.clip(diff * 2, 0, 255).astype(np.uint8))
side = Image.new('RGB', (1080 * 3 // 2, 540), 'white')
side.paste(ref.resize((540, 540)), (0, 0)); side.paste(last.resize((540, 540)), (540, 0)); side.paste(vis.convert('RGB').resize((540, 540)), (1080, 0))
side.save(D + 'accuracy.png')

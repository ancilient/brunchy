"""Vendor app logo images, from the real vendor badge (app icon/original/brunchy-vendor-logo.png).

  assets/brand/logo.png    the badge cut out along its disc (gloss and gradient kept), for the app's screens
  assets/app-icon.png      the same disc at 1024 px, transparent outside, for flutter_launcher_icons
  assets/brand/burger.png  just the burger (no disc / text), rendered from the vendor splash vector, for menu items
                           without a photo

Run after `BRUNCHY_PROFILE=vendor python build.py`, then in vendor_app: dart run flutter_launcher_icons
"""
import copy, json, os, subprocess, tempfile
os.environ.setdefault('BRUNCHY_PROFILE', 'vendor')
from PIL import Image, ImageDraw
from lottie import objects
from lottie.exporters.svg import export_svg
from parts import fit_disc, UP, SRC as BADGE

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'vendor_app', 'assets') + os.sep
SPLASH = APP + 'splash/brunchy_vendor_splash.json'
TMP = os.path.join(tempfile.gettempdir(), 'brunchy_vendor_render') + os.sep
CHROME = r'C:/Program Files/Google/Chrome/Application/chrome.exe'
os.makedirs(TMP, exist_ok=True)


def disc_cutout(size):
    """The badge's disc with an anti-aliased transparent outside (mask drawn 4x, then reduced)."""
    badge = Image.open(BADGE).convert('RGB')
    cx, cy, r = [v / UP for v in fit_disc()]
    r -= 1.5  # stay just inside the soft edge
    crop = badge.crop((round(cx - r), round(cy - r), round(cx + r), round(cy + r)))
    mask = Image.new('L', (crop.width * 4, crop.height * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, crop.width * 4 - 1, crop.height * 4 - 1), fill=255)
    out = crop.convert('RGBA')
    out.putalpha(mask.resize(crop.size, Image.LANCZOS))
    return out.resize((size, size), Image.LANCZOS)


disc_cutout(288).save(APP + 'brand/logo.png', optimize=True)
disc_cutout(1024).save(APP + 'app-icon.png', optimize=True)

# Burger only: drop the disc, its shine, the bite (it only makes sense on the disc), text and effects.
doc = json.load(open(SPLASH))
skip = ('disc', 'gloss', 'ripple', 'crumbs', 'bites')
doc['layers'] = [l for l in doc['layers'] if not (l['nm'] in skip or l['nm'].startswith('letter') or l['nm'].startswith('vendor-'))]
svg = TMP + 'burger.svg'
with open(svg, 'w') as fh:
    export_svg(objects.Animation.load(doc), fh, frame=int(doc['op']) - 1)
html = TMP + 'burger.html'
open(html, 'w').write('<html><body style="margin:0;background:transparent"><img src="burger.svg" width="2160" height="2160"></body></html>')
png = TMP + 'burger.png'
subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--default-background-color=00000000',
                '--window-size=2160,2160', f'--screenshot={png}', 'file:///' + html], capture_output=True)
burger = Image.open(png).convert('RGBA')
burger = burger.crop(burger.getbbox())
s = max(burger.size)
sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
sq.alpha_composite(burger, ((s - burger.width) // 2, (s - burger.height) // 2))
sq.resize((192, 192), Image.LANCZOS).save(APP + 'brand/burger.png', optimize=True)
print('wrote logo.png, app-icon.png, burger.png')

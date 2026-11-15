# Splash animation generator

Builds `assets/splash/brunchy_splash.json` (Lottie, 1080×1080, transparent, 60 fps, 3 s) from the real
Brunchy logo. The logo is traced straight from the 4096 px master, so the final frame matches it exactly.

```
pip install numpy pillow lottie        # lottie is only needed for preview.py
python build.py                        # writes ../../assets/splash/brunchy_splash.json
python preview.py                      # contact sheet + accuracy diff in your temp folder (needs Chrome)
```

The master logo path defaults to `D:/Brunchy/app icon/master/brunchy-icon-4096.png`; set `BRUNCHY_LOGO` to use another.

| File | What it does |
|---|---|
| `parts.py` | Splits the master into parts by its flat colours (buns, patty, cheese, smile, seeds, letters) |
| `tracer.py` | Connected components, pixel-edge contour tracing, smoothing, Douglas-Peucker simplification |
| `build.py` | Fits the disc, the uneaten bun (mirrored dome) and the two bite circles, then writes the keyframed Lottie |
| `preview.py` | Renders frames through python-lottie's SVG export and headless Chrome |

Timeline: disc pops (0–0.4 s) → burger builds itself (0.2–0.9 s) → seeds and smile (0.9–1.2 s) →
the bite with crumbs and a ripple (1.3–1.85 s) → "Brunchy" letters rise in (1.8–2.5 s) → hold.
The "A product of ANCILIENT" line is drawn by Flutter (`SplashLogo`), so it always sits above the
gesture bar whatever the screen shape.

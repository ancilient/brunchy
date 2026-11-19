# Splash animation generator

Builds `assets/splash/brunchy_splash.json` (Lottie, 1080×1080, transparent, 60 fps, 3 s) from the real
Brunchy logo (`D:/Brunchy/app icon/original/brunchy-logo-round.jpeg`). The logo is upscaled 3× and traced,
so the final frame matches it (mean difference ≈ 2/255, mostly JPEG noise).

```
pip install numpy pillow lottie        # lottie is only needed for preview.py
python build.py                        # writes ../../assets/splash/brunchy_splash.json
python preview.py                      # contact sheet + accuracy diff in your temp folder (needs Chrome)
```

The vendor app has its own logo (glossy aqua disc, smile, cheese, "— Vendor —"): `BRUNCHY_PROFILE=vendor python build.py` writes
`vendor_app/assets/splash/brunchy_vendor_splash.json`, then `python vendor_assets.py` makes the vendor logo, launcher-icon
and burger images (preview with `BRUNCHY_PROFILE=vendor python preview.py`).

The logo path defaults to `D:/Brunchy/app icon/original/brunchy-logo-round.jpeg`; set `BRUNCHY_LOGO` to use another.

| File | What it does |
|---|---|
| `parts.py` | Splits the logo into parts by its flat colours and finds the disc (buns, patty, seeds, letters) |
| `tracer.py` | Connected components, pixel-edge contour tracing, smoothing, Douglas-Peucker simplification |
| `build.py` | Rebuilds the uneaten bun (mirrors only the bitten corner), fits the two bite circles, writes the keyframed Lottie |
| `vendor_assets.py` | Vendor logo + launcher icon (cut from the vendor badge) and the burger placeholder (from the vendor vector) |
| `preview.py` | Renders frames through python-lottie's SVG export and headless Chrome |

Timeline: disc pops (0–0.4 s) → burger builds itself (0.2–0.8 s) → seeds pop (0.9–1.15 s) →
the bite with crumbs and a ripple (1.3–1.85 s) → "Brunchy" letters rise in (1.8–2.5 s) → hold.
The "A product of ANCILIENT" line is drawn by Flutter (`SplashLogo`), so it always sits above the
gesture bar whatever the screen shape.

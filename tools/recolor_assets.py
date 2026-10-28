"""Recolour the pre-rendered 3D tile objects for each theme in themes.js.

The originals in assets/ are the Gulaal theme. Every pixel is matched to the nearest of its four
role hues (c1..c4) and moved to that role's hue in the target theme, keeping light and shade.
Run from the repo root: python3 tools/recolor_assets.py
"""
import colorsys, os, re
import numpy as np
from PIL import Image

OBJECTS = ['ring', 'gas', 'card', 'pPink', 'pViolet', 'pCyan', 'play']
src = open('themes.js').read()
themes = {}
for name, body in re.findall(r"^\s+(\w+):\s+\{(.*?)\},?$", src, re.M):
    themes[name] = {k: v for k, v in re.findall(r"(c[1-4]): '#([0-9A-Fa-f]{6})'", body)}
base = themes.pop('gulaal')

def hsv(h): return colorsys.rgb_to_hsv(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))

def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 0
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0); gc = np.where(m, (mx - g) / np.where(m, d, 1), 0); bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2 + rc - bc, 4 + gc - rc))
    h = np.where(m, (h / 6) % 1, 0)
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1), 0)
    return np.stack([h, s, mx], -1)

def hsv_to_rgb(x):
    h, s, v = x[..., 0], x[..., 1], x[..., 2]
    i = np.floor(h * 6).astype(int) % 6; f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    sel = [np.stack(c, -1) for c in ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))]
    out = np.zeros(x.shape)
    for k in range(6): out = np.where((i == k)[..., None], sel[k], out)
    return out

for name, t in themes.items():
    os.makedirs(f'assets/{name}', exist_ok=True)
    for obj in OBJECTS:
        im = np.array(Image.open(f'assets/{obj}.png').convert('RGBA')).astype(float) / 255
        x = rgb_to_hsv(im[..., :3]); hh = x[..., 0] * 360
        src_h = [hsv(base[r])[0] * 360 for r in ('c1', 'c2', 'c3', 'c4')]
        dist = np.stack([np.minimum(abs(hh - h), 360 - abs(hh - h)) for h in src_h])
        idx = dist.argmin(0); out = hh.copy()
        for k, r in enumerate(('c1', 'c2', 'c3', 'c4')):
            nh, ns, _ = hsv(t[r]); m = idx == k
            out[m] = (hh[m] - src_h[k] + nh * 360) % 360
            x[..., 1][m] = np.clip(x[..., 1][m] * (0.6 + 0.6 * ns), 0, 1)
        x[..., 0] = out / 360
        im[..., :3] = hsv_to_rgb(x)
        Image.fromarray((im * 255).round().astype('uint8')).save(f'assets/{name}/{obj}.png', optimize=True)
    print(name, 'done')

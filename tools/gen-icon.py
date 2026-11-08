# App icon: pre-dawn sky, a flat marsh horizon, the sun's upper limb just
# under it. That's the moment the app is about: light is legal 30 minutes
# before the sun shows.   uv run --with pillow tools/gen-icon.py
from PIL import Image, ImageDraw, ImageFilter
import math, os

S = 1024
img = Image.new("RGB", (S, S))
px = img.load()
top, mid, low = (10, 14, 32), (38, 44, 92), (236, 128, 52)
H = int(S * 0.64)  # horizon
for y in range(S):
    if y < H:
        t = y / H
        a, b, u = (top, mid, t / 0.62) if t < 0.62 else (mid, low, (t - 0.62) / 0.38)
        u = max(0, min(1, u)) ** 1.6
        c = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))
    else:
        t = (y - H) / (S - H)
        c = tuple(int(v * (0.30 - 0.18 * t)) for v in (60, 70, 120))
    for x in range(S):
        px[x, y] = c

glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
cx, r = S // 2, 210
for k in range(40, 0, -1):
    rr = r + k * 9
    g.ellipse([cx - rr, H + 40 - rr, cx + rr, H + 40 + rr], fill=(255, 150, 60, int(5 + 1.2 * (40 - k))))
glow = glow.filter(ImageFilter.GaussianBlur(30))
img.paste(glow, (0, 0), glow)

d = ImageDraw.Draw(img)
# the sun, mostly below the horizon
d.ellipse([cx - r, H + 40 - r, cx + r, H + 40 + r], fill=(255, 196, 92))
d.rectangle([0, H, S, S], fill=None)
# water below the horizon covers the sun; redraw it with streaks
for y in range(H, S):
    t = (y - H) / (S - H)
    c = tuple(int(v * (0.30 - 0.18 * t)) for v in (60, 70, 120))
    d.line([(0, y), (S, y)], fill=c)
for i, w in enumerate([360, 280, 210, 150, 100, 60]):
    y = H + 22 + i * 34
    d.rounded_rectangle([cx - w // 2, y, cx + w // 2, y + 10], radius=5, fill=(255, 170, 70, 255))
# cattails on the left, a duck-hunter's horizon
for x, h, lean in [(120, 210, -8), (160, 260, 4), (196, 180, -3), (860, 230, 6), (900, 170, -5)]:
    d.line([(x, H + 4), (x + lean, H - h)], fill=(8, 10, 20), width=9)
    d.rounded_rectangle([x + lean - 13, H - h - 5, x + lean + 13, H - h + 70], radius=13, fill=(8, 10, 20))
d.rectangle([0, H - 3, S, H + 3], fill=(8, 10, 20))

out = os.path.join(os.path.dirname(__file__), "..", "App", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
img.save(out)
print("wrote", out)

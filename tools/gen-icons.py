# App icons, in ducktyping.dev's pixel style: 32x32 art (the favicon's grid)
# scaled 32x to 1024. One shared backdrop, a marsh half an hour before
# sunrise (the SceneLegalLight palette), and a subject per icon:
#   AppIcon          the dawn itself: sun under the tree line, cattails
#   AppIcon-Mallard  the favicon's drake head, pixel for pixel
#   AppIcon-Teal     blue-winged teal drake: slate head, white crescent
#   AppIcon-Deer     whitetail buck, head-on
#   AppIcon-Turkey   strutting tom, fan up
# Writes the asset catalog icon sets plus small previews for the in-app picker.
#   uv run --with pillow tools/gen-icons.py
import json, os, math
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "App", "Assets.xcassets")
N = 32

def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# ── backdrop ────────────────────────────────────────────────────────────────
SKY = [  # (rows, colour): night overhead, colour at the horizon
    (4, "#081210"), (4, "#0b1815"), (3, "#10201c"), (3, "#14262a"),
    (3, "#1a2a2a"), (2, "#2c3333"), (2, "#4a3d33"), (2, "#7a5638"), (1, "#b06a38"),
]
HORIZON = sum(r for r, _ in SKY)  # 24
GROUND = "#0a1512"
WATER = ["#0b1a1e", "#0a171a", "#091416", "#081210"]

def backdrop(sun=True, trees=True):
    img = [[None] * N for _ in range(N)]
    y = 0
    for rows, c in SKY:
        for _ in range(rows):
            for x in range(N): img[y][x] = hexc(c)
            y += 1
    for yy in range(HORIZON, N):
        for x in range(N): img[yy][x] = hexc(WATER[min(len(WATER) - 1, (yy - HORIZON) // 2)])
    # stars
    for (x, yy) in [(4, 2), (13, 4), (27, 1), (21, 6), (8, 8), (30, 9)]:
        img[yy][x] = hexc("#8fb0a2")
    if sun:  # glow just under the tree line, a sliver on the water
        for yy in range(HORIZON - 4, HORIZON):
            for x in range(N):
                d = math.hypot((x - 22) / 1.6, (yy - HORIZON) * 1.0)
                if d < 6:
                    a = (6 - d) / 6 * 0.55
                    r, g, b, _ = img[yy][x]
                    img[yy][x] = (int(r + (255 - r) * a), int(g + (180 - g) * a), int(b + (84 - b) * a), 255)
        for x in range(18, 27): img[HORIZON + 1][x] = hexc("#ffb454")
        for x in range(20, 25): img[HORIZON + 3][x] = hexc("#e0823d")
        for x in range(21, 24): img[HORIZON + 5][x] = hexc("#7a5638")
    if trees:  # ragged tree line on the horizon
        line = [0, 1, 1, 2, 3, 2, 1, 1, 2, 2, 1, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 3, 3, 2, 1, 1, 2]
        for x in range(N):
            for k in range(line[x] + 1):
                img[HORIZON - k][x] = hexc(GROUND)
    return img

def put(img, x, y, c):
    if 0 <= x < N and 0 <= y < N and c is not None: img[y][x] = hexc(c) if isinstance(c, str) else c

def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w): put(img, xx, yy, c)

def grid(img, rows, pal, ox=0, oy=0, mirror=False):
    """ASCII art; '.' is transparent. mirror: rows are the left half, reflected."""
    for y, row in enumerate(rows):
        full = row + row[::-1] if mirror else row
        for x, ch in enumerate(full):
            if ch != "." and ch != " ": put(img, ox + x, oy + y, pal[ch])

def cattail(img, x, top, lean=0):
    for y in range(top, HORIZON + 3): put(img, x + (lean if y < top + 3 else 0), y, "#06100c")
    rect(img, x - 1 + lean, top + 1, 3, 5, "#2a1c12")
    put(img, x + lean, top, "#06100c")

# ── subjects ────────────────────────────────────────────────────────────────

def dawn():
    img = backdrop()
    for x, top, lean in [(3, 13, 0), (6, 10, 0), (9, 15, 0), (27, 12, 0), (30, 16, 0)]:
        cattail(img, x, top, lean)
    # a decoy pair on the water
    for dx in (12, 15):
        rect(img, dx, HORIZON + 3, 3, 1, "#0f1d18")
        put(img, dx + 2, HORIZON + 2, "#0f1d18")
    return img

def mallard(head="#1fbf7e", sheen="#2bd98e", shadow="#178a59", bill=True, teal=False):
    img = backdrop(sun=True)
    # the favicon drake, rect for rect (head up/right, chest to the bottom)
    oy = 3
    for (x, y, w, h) in [(12, 6, 8, 2), (10, 8, 12, 2), (8, 10, 16, 2), (8, 12, 16, 2), (8, 14, 14, 2), (10, 16, 10, 2)]:
        rect(img, x, y + oy, w, h, head)
    for (x, y, w, h) in [(12, 6, 6, 2), (10, 8, 7, 2), (8, 10, 6, 2)]:
        rect(img, x, y + oy, w, h, sheen)
    for (x, y, w, h) in [(8, 15, 14, 1), (10, 16, 10, 2)]:
        rect(img, x, y + oy, w, h, shadow)
    rect(img, 17, 10 + oy, 3, 3, "#06110d"); put(img, 17, 10 + oy, "#bfe6d3")
    if teal:
        # the white crescent in front of the eye, top of head darker
        for (x, y) in [(21, 9), (22, 10), (22, 11), (22, 12), (22, 13), (22, 14), (21, 15)]:
            put(img, x, y + oy, "#f0f5f1")
        rect(img, 12, 6 + oy, 8, 1, "#2c3448")
        # dark bill
        rect(img, 24, 12 + oy, 6, 2, "#3b464f"); rect(img, 24, 14 + oy, 5, 2, "#2c353c")
        rect(img, 24, 12 + oy, 6, 1, "#6b7a86"); put(img, 29, 13 + oy, "#2c353c")
        # speckled tan breast
        for (x, y, w, h) in [(10, 18, 10, 2), (11, 20, 9, 2), (12, 22, 8, 2), (12, 24, 7, 2), (13, 26, 5, 2)]:
            rect(img, x, y + oy, w, h, "#b98a5a")
        for (x, y) in [(11, 19), (14, 18), (17, 19), (13, 21), (16, 21), (19, 20), (14, 23), (17, 23), (15, 25), (13, 25), (16, 27)]:
            put(img, x, y + oy, "#5a3a22")
    else:
        rect(img, 24, 12 + oy, 7, 2, "#ffb454"); rect(img, 24, 14 + oy, 6, 2, "#ffb454")
        rect(img, 24, 12 + oy, 7, 1, "#ffd08a"); rect(img, 24, 15 + oy, 6, 1, "#e0823d"); put(img, 27, 12 + oy, "#c9852f")
        rect(img, 10, 18 + oy, 10, 2, "#dfe8e2"); rect(img, 10, 18 + oy, 10, 1, "#f0f5f1")
        rect(img, 11, 20 + oy, 8, 2, "#8a5a34"); rect(img, 12, 22 + oy, 7, 2, "#7a4e2c")
        rect(img, 13, 24 + oy, 5, 2, "#6e4426"); rect(img, 11, 20 + oy, 2, 4, "#9a6a3e")
        rect(img, 13, 26 + oy, 5, 3, "#6e4426")
    return img

def teal():
    return mallard(head="#56637e", sheen="#6f7aa0", shadow="#3f4a63", teal=True)

def deer():
    img = backdrop()
    pal = {"A": "#d9c7a0", "a": "#a8946c", "b": "#8a5a34", "B": "#6e4426", "l": "#b98a5a",
           "w": "#e8e0d0", "k": "#06110d", "e": "#c79a7a", "s": "#bfe6d3"}
    left = [  # left half (16 wide), mirrored
        "................",
        "..A.............",
        "..A....A........",
        ".AA....A...A....",
        ".A.....A...A....",
        ".A....AA..AA....",
        ".AA..AA..AA.....",
        "..AaAA..AA......",
        "..aAAAAAA.......",
        "....aAAA........",
        "......AA........",
        ".bbb...aAB......",
        "beeebb..bBBbbbbb",
        ".beeebbbbbbbbbbb",
        "..bbbbbbbbbbblll",
        "......Bbbbbbblll",
        "......wBkkBbblll",
        ".......Bksbbbbll",
        "........Bbbbbbll",
        "........Bbbbbbll",
        ".........Bbbbbll",
        ".........Bbbbbll",
        "..........Bbbbll",
        "..........Bbbbll",
        "...........Bbbkk",
        "...........Bbkkk",
        "............Bwww",
        ".........Bbbbbbb",
        "........Bbbbbwww",
        ".......Bbbbbbwww",
        "......Bbbbbbbbbb",
        ".....Bbbbbbbbbbb",
    ]
    grid(img, left, pal, mirror=True)
    return img

def turkey():
    img = backdrop()
    cx, cy = 15.5, 19.0
    # the fan: concentric bands, feather seams every ~15°, tan tips
    for y in range(N):
        for x in range(N):
            dx, dy = x - cx, (y - cy) * 1.08
            r = math.hypot(dx, dy)
            if dy > 3 or r > 15.2: continue
            ang = math.degrees(math.atan2(dy, dx))
            seam = (round(ang) % 14) == 0 and r > 6
            if r > 13.6: c = "#e2c48e"          # tips
            elif r > 12.6: c = "#1a120c"        # dark band
            elif r > 10.0: c = "#7a5232"
            elif r > 9.0: c = "#1a120c"
            else: c = "#5e3e24"
            if seam and r <= 13.6: c = "#2a1c12"
            put(img, x, y, c)
    # body: a puffed bronze breast with barring, wings drooped at the sides
    for y in range(14, N):
        for x in range(N):
            dx, dy = (x - cx) / 7.4, (y - 24.0) / 8.6
            if dx * dx + dy * dy <= 1:
                c = "#2e2216" if (y % 3) else "#4e3820"
                if abs(dx) > 0.72: c = "#1c140e"            # wing edge
                put(img, x, y, c)
    for y in range(18, 30): put(img, 15 + (y % 2), y, "#0a0706")  # beard
    # head: white crown, blue face, red wattle and snood
    rect(img, 14, 8, 4, 2, "#e8eef4")
    rect(img, 13, 10, 6, 3, "#7fb4e8")
    put(img, 14, 11, "#06110d"); put(img, 17, 11, "#06110d")
    rect(img, 15, 12, 2, 1, "#c9b48a")                  # beak
    rect(img, 14, 13, 4, 2, "#d0423a"); rect(img, 15, 15, 2, 2, "#b0302a")  # wattle
    put(img, 16, 12, "#d0423a"); put(img, 16, 13, "#d0423a")               # snood
    rect(img, 14, 17, 4, 1, "#2a2018")  # neck into body
    return img

ICONS = [("AppIcon", dawn), ("AppIcon-Mallard", mallard), ("AppIcon-Teal", teal),
         ("AppIcon-Deer", deer), ("AppIcon-Turkey", turkey)]

def write_icon(name, art):
    small = Image.new("RGBA", (N, N))
    for y in range(N):
        for x in range(N): small.putpixel((x, y), art[y][x])
    big = small.resize((1024, 1024), Image.NEAREST).convert("RGB")
    d = os.path.join(ASSETS, f"{name}.appiconset"); os.makedirs(d, exist_ok=True)
    big.save(os.path.join(d, "icon-1024.png"))
    json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, "Contents.json"), "w"), indent=1)
    # preview for the in-app chooser (alternate icons aren't loadable as images)
    p = os.path.join(ASSETS, f"Preview-{name}.imageset"); os.makedirs(p, exist_ok=True)
    small.resize((192, 192), Image.NEAREST).convert("RGB").save(os.path.join(p, "preview.png"))
    json.dump({"images": [{"filename": "preview.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
               "properties": {"template-rendering-intent": "original"}}, open(os.path.join(p, "Contents.json"), "w"), indent=1)
    return big

sheet = Image.new("RGB", (5 * 260 + 20, 280), (40, 40, 40))
for i, (name, fn) in enumerate(ICONS):
    big = write_icon(name, fn())
    sheet.paste(big.resize((240, 240), Image.NEAREST), (20 + i * 260, 20))
os.makedirs(os.path.join(ROOT, "tools", "shots"), exist_ok=True)
sheet.save(os.path.join(ROOT, "tools", "shots", "icons.png"))
print("wrote", len(ICONS), "icons + tools/shots/icons.png")

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


HERE = Path(__file__).resolve().parent
OUT = HERE / "output"
RAW = HERE / "raw"
FRAME_PNG = HERE / "frames" / "iphone-16.png"
FRAME_PNG_IPAD = HERE / "frames" / "ipad-13.png"
BACKGROUND = HERE / "backgrounds" / "blackboard.jpg"

# Simalytics has no custom accent color (the app rides the system tint) and its
# icon is a white monochrome glyph, so the marketing palette is intentionally
# monochrome: white ink on the dark chalkboard backdrop. If you later add a brand
# accent, wire it in here.
WHITE = (255, 255, 255)
DIM = (198, 202, 208)

DEVICES = {
    "iphone-6.9": (1290, 2796),
    "ipad-13": (2064, 2752),
}

# Chalkboard backdrop transform. backgrounds/blackboard.jpg is already a
# 2400x3600 portrait crop of the source grunge texture, so it cover-fits both
# canvases with no rotation. rot: "0"/"90cw"/"90ccw"/"180". zoom: >1 crops
# tighter. anchor: (x, y) in 0..1 picks which part of the covered image stays in
# frame. The texture is a dark vignette (near-black edges, faintly lit centre),
# so a light top scrim is enough to seat the white headline; the floor is gentle.
BG = {
    "rot": "0",
    "zoom": 1.0,
    "anchor": (0.5, 0.5),
    "flip": False,
    "scrim_top": 120,
    "scrim_bottom": 40,
    "scrim_color": (6, 8, 10),
}

_ROT = {
    "0": None,
    "90cw": Image.ROTATE_270,
    "90ccw": Image.ROTATE_90,
    "180": Image.ROTATE_180,
}

# iPhone 16 frame geometry, in the SVG's 391-wide viewBox units. Scaled to the
# rasterized PNG at load time. glass = live screen rect; di = Dynamic Island.
FRAME_VB_W = 391.0
GLASS_VB = (13, 10, 378, 775)
GLASS_RX_VB = 52
DI_VB = (140, 24, 250, 55)
DI_RX_VB = 15.5

# A real 6.9" screenshot is 1320x2868 (aspect 0.4603). The SVG's glass opening is
# ~3.7% too wide for that, so a straight cover-fit had to crop the status bar and
# tab bar to fill it. We instead stretch the frame vertically at load so the glass
# matches this aspect exactly: the capture then maps 1:1 (no crop, no squish) and
# the clock lands aligned with the Dynamic Island.
SCREEN_ASPECT = 1320 / 2868

# iPad Pro 13" frame geometry, in the SVG's 707-wide viewBox units
# (frames/ipad-13.svg). glass = live screen rect, taken from the SVG's screen
# mask. There's no Dynamic Island, and the glass aspect (639.835/852.898 = 0.7502)
# already matches a real 2064x2752 capture (0.7500), so — unlike the iPhone — no
# vertical stretch is needed; the capture maps ~1:1 into the glass.
IPAD_FRAME_VB_W = 707.0
IPAD_GLASS_VB = (33.5825, 33.5509, 673.417, 886.449)
IPAD_GLASS_RX_VB = 12.37

# Slide list. `screen` matches the raw/<device>/NN-<screen>.png capture suffix
# that capture.sh emits (SIMALYTICS_SCREENSHOT_TAB value), and the order sets the
# NN- prefix. Headlines are placeholders — refine copy alongside the captures.
# Phase 1 covers the three marketing-worthy top-level tabs the harness launches
# straight into; add poster-wall grids / detail views as a later pass.
SLIDES = [
    {"title": "All your shows, movies, and anime.", "screen": "lists"},
    {"title": "Always know what to watch next.", "screen": "upnext"},
    {"title": "See what everyone's watching.", "screen": "explore"},
    {"title": "Your whole collection at a glance.", "screen": "grid"},
]

# Headline weight. San Francisco (SFNS.ttf) is a variable font; we select a named
# weight off its wght axis so the marketing headline carries the same confident
# weight as the app's own bold titles instead of a thin Regular that gets lost on
# the dark backdrop. Options: "Regular"/"Medium"/"Semibold"/"Bold"/"Heavy".
HEADLINE_WEIGHT = "Bold"

# wght-axis coordinate per named weight (SF's Weight axis runs 1-1000, Regular=400).
_WEIGHTS = {"Regular": 400, "Medium": 500, "Semibold": 600, "Bold": 700, "Heavy": 860}


def font(size: int, weight: str = "Regular") -> ImageFont.FreeTypeFont:
    for candidate in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Avenir Next.ttc",
    ):
        try:
            fnt = ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
        # SFNS is variable: pin axes (Width=100, Optical Size=96 for display-tuned
        # letterforms, GRAD=400) and set the requested weight. Non-variable
        # fallbacks silently skip this and render at their default weight.
        if candidate.endswith("SFNS.ttf") and weight in _WEIGHTS:
            try:
                fnt.set_variation_by_axes([100, 96, 400, _WEIGHTS[weight]])
            except (OSError, ValueError):
                pass
        return fnt
    return ImageFont.load_default()


def wrapped_lines(draw, text, max_width, fnt) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        test = f"{current} {word}".strip()
        if draw.textbbox((0, 0), test, font=fnt)[2] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def cover(image: Image.Image, size, zoom: float = 1.0, anchor=(0.5, 0.5)) -> Image.Image:
    """Scale to fully cover `size` (crop overflow), then crop at `anchor`."""
    w, h = size
    ratio = max(w / image.width, h / image.height) * zoom
    resized = image.resize(
        (max(w, round(image.width * ratio)), max(h, round(image.height * ratio))),
        Image.Resampling.LANCZOS,
    )
    ax, ay = anchor
    x = round((resized.width - w) * ax)
    y = round((resized.height - h) * ay)
    return resized.crop((x, y, x + w, y + h))


def rounded_mask(size, radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def scrim(size, cfg=BG) -> Image.Image:
    """Vertical dark gradient: strong at top (protects the headline), soft floor."""
    w, h = size
    top, bottom = cfg["scrim_top"], cfg["scrim_bottom"]
    color = cfg["scrim_color"]
    strip = Image.new("RGBA", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        a = int(top * (1 - t) ** 1.5 + bottom * (t ** 2.4))
        px[0, y] = (*color, min(255, a))
    return strip.resize((w, h))


def backdrop(w: int, h: int, cfg=BG) -> Image.Image:
    """Chalkboard background: reorient/crop the source image and lay down the scrim."""
    img = Image.open(BACKGROUND).convert("RGB")
    transpose = _ROT[cfg["rot"]]
    if transpose is not None:
        img = img.transpose(transpose)
    if cfg["flip"]:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    base = cover(img, (w, h), zoom=cfg["zoom"], anchor=cfg["anchor"]).convert("RGBA")
    return Image.alpha_composite(base, scrim((w, h), cfg))


def raw_capture(device: str, index: int, screen: str):
    path = RAW / device / f"{index:02d}-{screen}.png"
    return Image.open(path).convert("RGB") if path.exists() else None


# The status bar is baked in natively at capture time: capture.sh sets
# `simctl status_bar override` (9:41, full battery, Wi-Fi, 4 signal bars) before
# the UI test runs, so the raw captures already carry a clean marketing status bar
# and no compositing-time retiming/redrawing is needed.


_FRAME_CACHE: tuple[Image.Image, float, float] | None = None


def _frame() -> tuple[Image.Image, float, float]:
    """Frame image with its glass opening stretched to SCREEN_ASPECT, plus the
    per-axis viewBox->pixel scales (sx, sy). sy > sx by the stretch factor."""
    global _FRAME_CACHE
    if _FRAME_CACHE is None:
        frame = Image.open(FRAME_PNG).convert("RGBA")
        sx = frame.width / FRAME_VB_W
        glass_w = (GLASS_VB[2] - GLASS_VB[0]) * sx
        glass_h = (GLASS_VB[3] - GLASS_VB[1]) * sx
        vstretch = (glass_w / SCREEN_ASPECT) / glass_h
        frame = frame.resize((frame.width, round(frame.height * vstretch)), Image.Resampling.LANCZOS)
        _FRAME_CACHE = (frame, sx, sx * vstretch)
    return _FRAME_CACHE


def iphone_frame(screenshot, target_w: int) -> Image.Image:
    """Composite a screenshot into the real iPhone 16 frame at native resolution,
    redraw the Dynamic Island on top, then scale to `target_w`."""
    frame, sx, sy = _frame()
    frame = frame.copy()
    gx0, gy0 = round(GLASS_VB[0] * sx), round(GLASS_VB[1] * sy)
    gx1, gy1 = round(GLASS_VB[2] * sx), round(GLASS_VB[3] * sy)
    glass = (gx1 - gx0, gy1 - gy0)

    if screenshot is not None:
        screen = cover(screenshot, glass, anchor=(0.5, 0.5)).convert("RGBA")
        frame.paste(screen, (gx0, gy0), rounded_mask(glass, round(GLASS_RX_VB * sx)))

    di = (round(DI_VB[0] * sx), round(DI_VB[1] * sy), round(DI_VB[2] * sx), round(DI_VB[3] * sy))
    ImageDraw.Draw(frame, "RGBA").rounded_rectangle(di, radius=round(DI_RX_VB * sy), fill=(6, 6, 8, 255))

    target_h = round(frame.height * target_w / frame.width)
    return frame.resize((target_w, target_h), Image.Resampling.LANCZOS)


_IPAD_FRAME_CACHE: Image.Image | None = None


def ipad_frame(screenshot, target_w: int) -> Image.Image:
    """Composite a screenshot into the real iPad Pro 13" frame at native
    resolution, then scale to `target_w`. No vertical stretch and no Dynamic
    Island (see the IPAD_* geometry note) — the capture maps ~1:1 into the glass."""
    global _IPAD_FRAME_CACHE
    if _IPAD_FRAME_CACHE is None:
        _IPAD_FRAME_CACHE = Image.open(FRAME_PNG_IPAD).convert("RGBA")
    frame = _IPAD_FRAME_CACHE.copy()
    s = frame.width / IPAD_FRAME_VB_W
    gx0, gy0 = round(IPAD_GLASS_VB[0] * s), round(IPAD_GLASS_VB[1] * s)
    gx1, gy1 = round(IPAD_GLASS_VB[2] * s), round(IPAD_GLASS_VB[3] * s)
    glass = (gx1 - gx0, gy1 - gy0)

    if screenshot is not None:
        screen = cover(screenshot, glass, anchor=(0.5, 0.5)).convert("RGBA")
        frame.paste(screen, (gx0, gy0), rounded_mask(glass, round(IPAD_GLASS_RX_VB * s)))

    target_h = round(frame.height * target_w / frame.width)
    return frame.resize((target_w, target_h), Image.Resampling.LANCZOS)


def device_shadow(frame: Image.Image, blur: int, dy: int):
    """Device-shaped soft shadow built from the frame's own alpha silhouette."""
    pad = blur * 3
    shape = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    shape.putalpha(frame.split()[-1].point(lambda a: a * 175 // 255))
    canvas = Image.new("RGBA", (frame.width + pad * 2, frame.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(shape, (pad, pad + dy))
    return canvas.filter(ImageFilter.GaussianBlur(blur)), pad


def draw_headline(base: Image.Image, title: str, x: int, y: int, max_width: int, scale: float):
    title_font = font(int(100 * scale), HEADLINE_WEIGHT)
    line_height = int(116 * scale)
    d = ImageDraw.Draw(base, "RGBA")
    for i, line in enumerate(wrapped_lines(d, title, max_width, title_font)[:2]):
        ly = y + i * line_height
        d.text((x + 2, ly + 3), line, fill=(0, 0, 0, 120), font=title_font)
        d.text((x, ly), line, fill=WHITE, font=title_font)


def compose(device: str, slide, index: int):
    w, h = DEVICES[device]
    img = backdrop(w, h)
    screenshot = raw_capture(device, index, slide["screen"])

    if device.startswith("iphone"):
        scale = w / 1290
        draw_headline(img, slide["title"], int(96 * scale), int(196 * scale), int(1110 * scale), scale)

        frame_w = int(1060 * scale)
        frame = iphone_frame(screenshot, frame_w)
        fx = (w - frame.width) // 2
        fy = int(560 * scale)
        shadow, spad = device_shadow(frame, blur=int(70 * scale), dy=int(34 * scale))
        img.alpha_composite(shadow, (fx - spad, fy - spad))
        img.alpha_composite(frame, (fx, fy))
    else:
        draw_headline(img, slide["title"], 170, 250, w - 340, 1.5)
        frame = ipad_frame(screenshot, 1500)
        fx = (w - frame.width) // 2
        fy = 700
        shadow, spad = device_shadow(frame, blur=90, dy=46)
        img.alpha_composite(shadow, (fx - spad, fy - spad))
        img.alpha_composite(frame, (fx, fy))

    out_dir = OUT / device
    out_dir.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(out_dir / f"{index:02d}-{slide['screen']}.png", optimize=True)


def main():
    count = 0
    for device in DEVICES:
        for i, slide in enumerate(SLIDES, 1):
            compose(device, slide, i)
            count += 1
    print(f"Generated {count} screenshots in {OUT}")


if __name__ == "__main__":
    main()

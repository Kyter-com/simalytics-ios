#!/usr/bin/env python3
"""Generate the detail-view parallax hero banner(s) for screenshot mode.

The movie/show detail views draw a landscape "fanart" banner behind the nav bar
(ParallaxBackgroundImage, /fanart/<key>_mobile.jpg). When no verified public-domain
landscape still is available, this script can derive a soft, cinematic color wash
from the title's already-public-domain poster. Output is written next to the posters
as pd-posters/<poster>-fanart.jpg, which ScreenshotMode.PosterURLProtocol serves for
the fixture's `fanart` key (see ScreenshotDetailFixtures).

    python3 marketing/app-store-screenshots/make-fanart.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

HERE = Path(__file__).resolve().parent
POSTERS = HERE / "pd-posters"

# Poster keys that need a derived `-fanart` fallback. Do not list titles with real
# verified-PD stills here, or this script would overwrite the cataloged source.
FANART_FOR: list[str] = []

BANNER = (1600, 900)  # landscape source; the app cover-fits it into a short banner


def make_fanart(poster_key: str) -> Path:
    src = POSTERS / f"{poster_key}.jpg"
    if not src.exists():
        raise FileNotFoundError(src)
    img = Image.open(src).convert("RGB")

    # Cover-fit the portrait poster into a landscape frame (crop, don't distort).
    w, h = BANNER
    ratio = max(w / img.width, h / img.height)
    resized = img.resize(
        (max(w, round(img.width * ratio)), max(h, round(img.height * ratio))),
        Image.Resampling.LANCZOS,
    )
    x = (resized.width - w) // 2
    y = (resized.height - h) // 2
    banner = resized.crop((x, y, x + w, y + h))

    # Soft cinematic wash: heavy blur keeps the palette but drops legible detail,
    # then pull saturation up a touch and brightness down so white nav-bar chrome
    # and the overlapping poster read cleanly on top.
    banner = banner.filter(ImageFilter.GaussianBlur(42))
    banner = ImageEnhance.Color(banner).enhance(1.18)
    banner = ImageEnhance.Brightness(banner).enhance(0.82)

    out = POSTERS / f"{poster_key}-fanart.jpg"
    banner.save(out, quality=88, optimize=True)
    return out


def main() -> None:
    for key in FANART_FOR:
        out = make_fanart(key)
        print(f"wrote {out.relative_to(HERE)}")


if __name__ == "__main__":
    main()

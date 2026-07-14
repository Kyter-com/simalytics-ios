# Simalytics App Store Screenshots

Generator + automation for App Store-ready iPhone and iPad marketing screenshots,
built on real captures of the live app running a **deterministic, fully offline,
public-domain fixture set**, composited onto a dark chalkboard backdrop in real
device frames.

Modeled on the SnipSnaps pipeline, adapted for a login-gated, SwiftData-backed
media tracker. **Every on-screen title and poster is public domain** — no Simkl
account, no network, and nothing copyrighted from Simkl's CDN — so the shots are
safe for App Store review.

## Outputs

- `output/iphone-6.9/*.png` — 1290 × 2796 (App Store iPhone 6.9")
- `output/ipad-13/*.png` — 2064 × 2752 (App Store iPad 13")

## One-shot regenerate (layout only)

If `raw/` already has captures and you only touched the marketing layout/copy:

```bash
python3 marketing/app-store-screenshots/generate.py
```

## Full reproduce (real captures end-to-end)

```bash
# iPhone 17 Pro Max @ iOS 26.x
marketing/app-store-screenshots/capture.sh <iphone-sim-udid> \
  marketing/app-store-screenshots/raw/iphone-6.9

# iPad Pro 13" @ iOS 26.x
marketing/app-store-screenshots/capture.sh <ipad-sim-udid> \
  marketing/app-store-screenshots/raw/ipad-13

# Composite the marketing layouts
python3 marketing/app-store-screenshots/generate.py
```

`xcrun simctl list devices available` lists simulator UDIDs. `capture.sh` requires
both the iOS 26+ SDK and an iOS 26+ simulator runtime so the captured system chrome
renders with Liquid Glass; it exits before building when either requirement is not met.

## How the data gets in (public domain, offline)

Simalytics hard-gates Explore + Up Next behind login, and every list/up-next/
explore screen reads from **local SwiftData** (the network only writes into it).
Because Apple reviews the poster **images**, and Simkl's CDN posters can be
copyrighted even for public-domain films, we don't sync a real account at all.
Instead a **DEBUG-only screenshot mode** (`simalytics/Utils/ScreenshotMode.swift`,
compiled out of Release) is switched on by launch env vars that `capture.sh` sets:

| env var | effect |
| --- | --- |
| `SIMALYTICS_SCREENSHOTS=1` | in-memory store pre-seeded with public-domain fixtures (`ScreenshotSeedData`); sync disabled; a sentinel token opens the Explore/Up Next gates (never networked, never stored); grid layout forced |
| `SIMALYTICS_SCREENSHOT_TAB=<tab>` | launch straight into `lists` \| `upnext` \| `explore` \| `settings` (tap-free capture) |
| `SIMALYTICS_SCREENSHOT_SCREEN=<screen>` | route the Lists tab to a sub-screen: `movies-grid` \| `tv-grid` (poster-wall grids) \| `movie-detail` (rich detail view). Empty = the Lists hub. |
| `SIMALYTICS_SCREENSHOT_HIDE_ANIME=1` | hide the Anime section/shelf for this capture; `capture.sh` sets it only for the Explore slide (early-B&W anime art clashes with the color shelves), so Lists still shows anime |
| `SIMALYTICS_SCREENSHOT_POSTER_DIR=<dir>` | local dir of public-domain poster JPEGs; `PosterURLProtocol` serves these for every `/posters/` **and** detail-view `/fanart/` request so nothing is fetched from Simkl |

Detail views are network-driven (they render from a live `getMovieDetails` fetch, not
the seeded store), so a rich offline detail capture needs an injected fixture:
`ScreenshotDetailFixtures` (DEBUG) returns a hand-built `MovieDetailsModel` for the
featured title and the view-model short-circuits to it in screenshot mode. Its poster
+ "Users Also Watched" row ride the `/posters/` interceptor; its parallax banner rides
`/fanart/` (a verified-PD studio still, or a poster-derived fallback from
`make-fanart.py`); and
`ids.tmdb = nil` hides the cast row so no copyrighted TMDB photos appear.

Result: deterministic, offline, and guaranteed-PD captures with a small,
Release-inert code footprint.

### The public-domain assets

- **`pd-posters/<key>.jpg`** — verified public-domain poster images. Each fixture
  row's `poster` value is the `<key>`; the app builds `.../posters/<key>_m.jpg`
  and `PosterURLProtocol` returns `pd-posters/<key>.jpg`.
- **`ScreenshotSeedData.swift`** (in the app target, DEBUG) — the fixture rows
  (titles, years, statuses, episode progress, trending order). Regenerated from
  the vetted catalog; keep titles + `poster` keys in sync with `pd-posters/`.

To change the media: add a PD poster JPEG to `pd-posters/`, add a matching row in
`ScreenshotSeedData.swift` (its `poster` = the filename without `.jpg`), rebuild,
re-run `capture.sh`.

## Visual style

- **Background** — `backgrounds/blackboard.jpg`, a dark chalkboard grunge texture
  (rotated to portrait + downscaled from the source). The `BG` dict in
  `generate.py` controls the crop and a legibility scrim behind the headline.
- **Palette** — monochrome white ink. Simalytics has no custom accent color and
  its icon is a white glyph, so white headlines on the dark backdrop read as
  on-brand. Wire an accent into `generate.py` if that changes.
- **iPhone frame** — real iPhone 16 mockup (`frames/iphone-16.*`); the SVG glass
  is ~3.7% too wide for a real 6.9" capture, so `iphone_frame()` stretches the
  frame vertically to `SCREEN_ASPECT` (capture maps 1:1; status bar on the Dynamic
  Island; tab bar intact). Dynamic Island redrawn; device-shaped shadow.
- **iPad frame** — real iPad Pro 13" mockup (`frames/ipad-13.*`); glass aspect
  already matches a real capture, so no stretch, no notch.
- **Status bar** — baked in natively by `capture.sh` (`simctl status_bar override`,
  9:41 / full battery / Wi-Fi / signal).

Re-rasterize a frame after editing its SVG (needs `librsvg`):

```bash
rsvg-convert -w 2000 -f png frames/iphone-16.svg -o frames/iphone-16.png
rsvg-convert -w 2400 -f png frames/ipad-13.svg   -o frames/ipad-13.png
```

## File layout

```
marketing/app-store-screenshots/
├── capture.sh          # boot -> build -> launch each tab/screen (fixture mode) -> screenshot
├── generate.py         # composites raw captures into marketing PNGs (iPhone + iPad)
├── seed-fixtures.py    # generates simalytics/Utils/ScreenshotSeedData.swift from pd-catalog.json
├── make-fanart.py      # derives fallback fanart when no verified-PD landscape still exists
├── backgrounds/        # blackboard.jpg — the composite backdrop
├── frames/             # <device>.svg sources + pre-rasterized <device>.png (iphone-16, ipad-13)
├── pd-posters/         # verified public-domain poster JPEGs (<key>.jpg)
├── raw/<device>/       # per-device captures (01-lists, 02-upnext, 03-explore)
├── output/<device>/    # composited App Store PNGs
└── .capture-runs/      # DerivedData build output (gitignored)
```

## Slides

`SLIDES` in `generate.py` (order sets the `NN-` prefix on each raw capture):

1. `01-lists` — the categorized watchlist (Movies / TV / Anime; anime shows here but
   its shelf is hidden on Explore)
2. `02-upnext` — Up Next, the "what to watch next" queue
3. `03-explore` — trending discovery
4. `04-grid` — the Movies poster-wall grid (`movies-grid` sub-screen)
5. `05-movie-detail` — a rich movie detail view (`movie-detail` sub-screen): hero
   banner, poster, metadata, synopsis, rating, and a "Users Also Watched" row

Sub-screens (grids, detail) are reached tap-free via `SIMALYTICS_SCREENSHOT_SCREEN`,
routed in `ContentView.listsTab` — no XCUITest target needed.

## Adding a slide

1. Make the screen reachable at launch (a new `SIMALYTICS_SCREENSHOT_TAB` value or
   an initial-navigation hook).
2. Add an entry to `SCREENS` in `capture.sh` (`"NN-name:tab"`).
3. Add a matching entry to `SLIDES` in `generate.py` (`screen` = the `NN-name`
   suffix; order sets the `NN-` prefix).
4. Re-run `capture.sh` for each device, then `generate.py`.

## Credits & licensing

- **On-screen media** — every title/poster in the screenshots is public domain. The
  posters in `pd-posters/` were sourced from Wikimedia Commons; `pd-catalog.json`
  records each one's title, year, PD license tag (`PD-US-expired` /
  `PD-US-no-notice` / `PD-US-not-renewed` / etc.), source page, and a `note` where the
  image needs context. Each was license-verified before inclusion. Note: PD status
  here is **US**-based; a few works may still be under copyright in other jurisdictions.
- **Color posters** — for liveliness we favor vivid color lithograph one-sheets, most
  of them pre-1929 (`PD-US-expired`, renewal-independent).
- **Same-character stand-ins** — genuine color PD *TV-show* poster art barely exists,
  so a few shows use a color PD *film/serial* poster of the same character (e.g. the
  Cisco Kid → *In Old Arizona* 1929; Sherlock Holmes → the 1922 Barrymore one-sheet;
  the Lone Ranger → the 1938 Republic serial). `POSTER_OVERRIDES` in `seed-fixtures.py`
  maps the show to the image; the list still shows the show's own name/year, and
  `pd-catalog.json` records each image's true film + license.
- **Detail-view banners** — prefer a real verified-PD landscape still and record its
  source/license in `pd-catalog.json`. The featured *His Girl Friday* banner is a
  subject-aware crop of a 1940 Columbia Pictures studio still tagged
  `PD-US-not-renewed` by Wikimedia Commons. When no safe still exists,
  `make-fanart.py` can derive a blurred color wash from the title's PD poster.
- **Anime** — no colorful public-domain anime exists (the safe options are early B&W).
  A few early PD anime titles are seeded so the Lists "Anime" section shows realistic
  counts, but **no anime poster appears in any captured slide** (the Lists hub is
  counts-only, the Explore anime shelf is hidden, none are "watching"), so all rows
  share one never-displayed real PD still (`namakura-gatana-1917`, the 1917 Dull Sword).
- **Backdrop** — `backgrounds/blackboard.jpg` is a photo by Peter Gargiulo on
  Unsplash (Unsplash License; free for commercial use), cropped and downscaled.
- **Device frames** — `frames/*.svg` are slimmed Figma device mockups (iPhone 16,
  iPad Pro 13"), shared with the SnipSnaps pipeline.

## Verify output dimensions

```bash
python3 - <<'PY'
from PIL import Image
from pathlib import Path
expected = {'iphone-6.9': (1290, 2796), 'ipad-13': (2064, 2752)}
for p in sorted(Path('marketing/app-store-screenshots/output').glob('*/*.png')):
    assert Image.open(p).size == expected[p.parent.name], p
    print('OK', p, Image.open(p).size)
PY
```

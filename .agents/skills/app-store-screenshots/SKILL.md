---
name: app-store-screenshots
description: Use when generating Apple App Store screenshots for Simalytics (iPhone + iPad), especially when the workflow should use real simulator captures of the live app running deterministic public-domain fixtures, composited into polished marketing layouts. Triggers on app store screenshots, iOS screenshots, iPad screenshots, marketing screenshots, screenshot generator.
---

# Simalytics App Store Screenshots

## Purpose

Create App Store-ready iPhone and iPad screenshots that combine **real captures of
the live app** with a polished marketing layout — a dark chalkboard backdrop, real
device frames, and a white headline. The app runs a **deterministic, offline,
public-domain fixture set**, so every visible title and poster is public domain and
safe for App Store review.

This skill is Apple-only. The full, working pipeline lives in
`marketing/app-store-screenshots/` — start there; this file is the why/gotchas.

## Core rules

- Prefer real captures of production views over hand-drawn mockups.
- One clear idea per slide; short, benefit-led copy readable at thumbnail size.
- Keep export dimensions exact: iPhone 6.9" `1290×2796`, iPad 13" `2064×2752`.
- Capture with the iOS 26+ SDK on an iOS 26+ simulator runtime so system chrome
  renders with Liquid Glass. `capture.sh` enforces both requirements.
- **Every on-screen poster and title must be public domain.** Apple reviews the
  poster *images*; a PD film can still have a copyrighted CDN poster, so we never
  fetch from Simkl — we serve verified-PD JPEGs from `pd-posters/`.
- All screenshot hooks are `#if DEBUG`; Release behavior is untouched.

## The data problem (Simalytics-specific)

Simalytics is **login-gated** and **SwiftData-backed**: Explore + Up Next are
blocked behind `auth.simklAccessToken.isEmpty`, and every list/up-next/explore view
reads from local SwiftData (the network only writes into it). We do **not** sync a
real account, because Simkl's CDN posters can be copyrighted even for PD films.

Instead, a DEBUG-only **fixture mode** (`simalytics/Utils/ScreenshotMode.swift`,
compiled out of Release) is driven by launch env vars that `capture.sh` sets:

- `SIMALYTICS_SCREENSHOTS=1` — build an **in-memory** `ModelContainer` pre-seeded
  with public-domain fixtures (`ScreenshotSeedData`), give `Auth` a **sentinel
  token** so the gates open (never networked, never stored), and disable sync
  (`syncLatestActivities` early-returns in this mode — see Sync.swift).
- `SIMALYTICS_SCREENSHOT_TAB=lists|explore|upnext|settings` — launch straight into
  a tab (tap-free, so `capture.sh` grabs it with `simctl io screenshot`).
- `SIMALYTICS_SCREENSHOT_SCREEN=<sub-screen>` — route the Lists tab to a sub-screen
  instead of the hub (`ContentView.listsTab`): `movies-grid` / `tv-grid` (poster-wall
  grids) or `movie-detail` (a rich detail view). Still tap-free.
- `SIMALYTICS_SCREENSHOT_HIDE_ANIME=1` — hide the Anime section/shelf for this
  capture. `capture.sh` sets it only for the Explore slide (its trending-anime art is
  early B&W and clashes with the color shelves); the Lists slide leaves anime shown.
- `SIMALYTICS_SCREENSHOT_POSTER_DIR=<dir>` — a host directory of PD poster JPEGs;
  `PosterURLProtocol` intercepts every `.../posters/<key>_m.jpg` **and**
  `.../fanart/<key>_mobile.jpg` request and returns `<dir>/<key>.jpg`, so no poster
  or banner is ever fetched from Simkl.

`ScreenshotMode.setUp()` also forces grid layout for the poster-wall slide.

Result: deterministic, offline, guaranteed-PD captures.

### Detail views (network-driven) need injected fixtures

Unlike the list/explore/up-next tabs (which read the seeded SwiftData store), the
detail views render entirely from a live `getMovieDetails`/`getShowDetails` fetch —
offline they'd hit the "unavailable" empty state. `ScreenshotDetailFixtures` (DEBUG)
returns a hand-built `MovieDetailsModel` + `MovieWatchlistModel` for the featured
title, and the view-models short-circuit to it when `ScreenshotMode.isActive`. Set
`ids.tmdb = nil` so `getCast` returns `[]` (the cast row self-hides — no copyrighted
TMDB actor photos), and point `fanart` at a `<poster>-fanart` key. Prefer a real
verified-PD landscape still with provenance recorded in `pd-catalog.json`; use
`make-fanart.py` for a poster-derived color-wash fallback only when no safe still exists.

### Public-domain assets

- `marketing/app-store-screenshots/pd-posters/<key>.jpg` — verified-PD poster
  images. Use images with an unambiguous PD tag (PD-US-expired / PD-US-no-notice /
  PD-US-not-renewed / CC0) — NOT CC-BY/CC-BY-SA/fair-use.
- `simalytics/Utils/ScreenshotSeedData.swift` (DEBUG) — GENERATED fixture rows; each
  row's `poster` value is the `<key>` and must have a matching `pd-posters/<key>.jpg`.
  Edit `seed-fixtures.py` (not the Swift) and regenerate.
- Prefer **vivid color** posters. The strongest, no-fuss PD basis is **pre-1929
  (`PD-US-expired`)** — renewal-independent; e.g. the 1920s color lithograph one-sheets
  (The Lost World, Ben-Hur, Robin Hood, Don Q…). Be wary of "not renewed" claims on
  major-studio 1929–1963 features — those are the disputed cases.
- **Same-character stand-ins:** genuine color PD *TV-show* poster art barely exists,
  so a few shows use a color PD *film/serial* poster of the same character via
  `POSTER_OVERRIDES` in `seed-fixtures.py` (identity key → poster-image key). The list
  keeps the show's name; the catalog records each image's true film + license.
- There is essentially **no colorful public-domain anime** (the safe options are early
  B&W, e.g. the 1917 Dull Sword). A small set of early PD anime is seeded so the Lists
  "Anime" section shows realistic counts, but **no anime poster is displayed in any
  captured slide** — the Lists hub is counts-only, the Explore anime shelf is hidden
  (`SIMALYTICS_SCREENSHOT_HIDE_ANIME`), and none are "watching" (so none reach Up Next).
  All anime rows share one real PD still (`namakura-gatana-1917`) as a never-shown
  placeholder poster.

## Workflow

1. Ensure `pd-posters/` and `ScreenshotSeedData` are in sync (matching keys).
2. `capture.sh <iphone-udid> raw/iphone-6.9` and `capture.sh <ipad-udid> raw/ipad-13`.
3. `python3 generate.py` to composite.
4. Verify exact dimensions and eyeball one iPhone + one iPad output.
5. Commit raw captures, outputs, the fixtures, the PD posters, and generator/hook
   changes. Verify no PD image slipped in that isn't actually PD.

## Layout / generator notes

- `generate.py` is PIL-only. `BG` controls the backdrop crop + legibility scrim;
  `SLIDES` is the ordered slide list (`screen` matches the `NN-name` raw file).
- iPhone frame glass is ~3.7% too wide for a real 6.9" capture, so the frame is
  stretched vertically to `SCREEN_ASPECT` (capture maps 1:1; status bar lands on the
  Dynamic Island; tab bar survives). iPad glass already matches — no stretch.
- Reserve fixed headline blocks so copy doesn't shift between slides. Keep the
  palette monochrome white unless a brand accent is introduced.
- Budget the iPad canvas (ratio ~0.75) in absolute pixels — don't just scale the
  iPhone coordinates, or frames overflow off-canvas.

## Gotchas

- **Status bar shows the sim's live clock / weak signal** — `capture.sh` runs
  `simctl status_bar override` before capturing. If it didn't apply, the sim is
  stale; `xcrun simctl erase <device>` and re-run.
- **Empty Lists / "Sign in to Simkl" on Explore & Up Next** — fixture mode isn't
  active. Confirm the build is Debug (hooks are `#if DEBUG`) and that
  `SIMALYTICS_SCREENSHOTS=1` reached the app (`SIMCTL_CHILD_*` in `capture.sh`).
- **Posters are gray placeholders** — `PosterURLProtocol` couldn't find a file:
  either `SIMALYTICS_SCREENSHOT_POSTER_DIR` is wrong/missing, or a fixture row's
  `poster` key has no matching `pd-posters/<key>.jpg`. (Simulator apps can read
  host paths, so an absolute path to the repo dir works.)
- **Seeding from a nonisolated context** — build the in-memory container's context
  with `ModelContext(container)`, not `container.mainContext` (main-actor-isolated).
- **A detail view shows "unavailable" / a blank banner** — detail screens are
  network-driven. Confirm `ScreenshotDetailFixtures` returns a model for the featured
  `simkl_id` (routed via `SIMALYTICS_SCREENSHOT_SCREEN=movie-detail` →
  `ContentView.listsTab`), and that its `fanart` key has a `pd-posters/<key>-fanart.jpg`
  (else the `/fanart/` request fails and the parallax banner renders empty).
- **A poster that isn't really PD** — the film being PD doesn't make a given poster
  image PD. Only bundle images whose hosting page shows a PD license tag; verify
  before committing.

## Verification checklist

- Raw iPhone + iPad captures exist at the expected resolutions (native iPad, not
  iPhone-compat letterboxed — Simalytics is `TARGETED_DEVICE_FAMILY = "1,2,7"`).
- Final output dimensions match App Store sizes.
- Every visible poster is a verified-PD image; no copyrighted artwork.
- Release build unaffected by the DEBUG hooks.

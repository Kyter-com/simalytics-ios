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
- `SIMALYTICS_SCREENSHOT_POSTER_DIR=<dir>` — a host directory of PD poster JPEGs;
  `PosterURLProtocol` intercepts every `.../posters/<key>_m.jpg` request and returns
  `<dir>/<key>.jpg`, so no poster is ever fetched from Simkl.

Result: deterministic, offline, guaranteed-PD captures.

### Public-domain assets

- `marketing/app-store-screenshots/pd-posters/<key>.jpg` — verified-PD poster
  images. Use images with an unambiguous PD tag (PD-US-expired / PD-US-no-notice /
  PD-US-not-renewed / CC0) — NOT CC-BY/CC-BY-SA/fair-use.
- `simalytics/Utils/ScreenshotSeedData.swift` (DEBUG) — fixture rows; each row's
  `poster` value is the `<key>` and must have a matching `pd-posters/<key>.jpg`.
- There is essentially **no public-domain anime**, so the anime slide is omitted.

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
- **Grids/details look empty** — those aren't top-level tabs; the tap-free harness
  only reaches tabs today. Add an initial-navigation hook or an XCUITest target to
  capture sub-screens; both reuse fixture mode.
- **A poster that isn't really PD** — the film being PD doesn't make a given poster
  image PD. Only bundle images whose hosting page shows a PD license tag; verify
  before committing.

## Verification checklist

- Raw iPhone + iPad captures exist at the expected resolutions (native iPad, not
  iPhone-compat letterboxed — Simalytics is `TARGETED_DEVICE_FAMILY = "1,2,7"`).
- Final output dimensions match App Store sizes.
- Every visible poster is a verified-PD image; no copyrighted artwork.
- Release build unaffected by the DEBUG hooks.

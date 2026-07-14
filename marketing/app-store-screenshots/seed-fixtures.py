#!/usr/bin/env python3
"""Generate the app's DEBUG screenshot fixtures from the verified PD catalog.

Reads pd-catalog.json (verified public-domain titles + poster keys) and the
status/episode assignments below, and writes:

    simalytics/Utils/ScreenshotSeedData.swift

Every `key` used here must have a matching pd-posters/<key>.jpg (served by
ScreenshotMode.PosterURLProtocol at capture time).

    python3 marketing/app-store-screenshots/seed-fixtures.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
CATALOG = HERE / "pd-catalog.json"
POSTERS = HERE / "pd-posters"
OUT = REPO / "simalytics" / "Utils" / "ScreenshotSeedData.swift"

# ---- Status / episode assignments -------------------------------------------
# Movies: key -> (status, rating|None, added_days_ago, watched_days_ago|None)
MOVIES = {
    "the-general-1926": ("completed", 9, 300, 80),
    "the-cabinet-of-dr-caligari-1920": ("completed", 9, 210, 60),
    "his-girl-friday-1940": ("completed", 8, 120, 30),
    "charade-1963": ("completed", 8, 90, 14),
    "the-kid-1921": ("completed", 9, 260, 70),
    "meet-john-doe-1941": ("completed", 8, 150, 40),
    "my-man-godfrey-1936": ("completed", 7, 100, 22),
    "a-star-is-born-1937": ("completed", 8, 200, 55),
    "the-stranger-1946": ("completed", 7, 70, 12),
    "detour-1945": ("completed", 7, 45, 9),
    "carnival-of-souls-1962": ("plantowatch", None, 8, None),
    "house-on-haunted-hill-1959": ("plantowatch", None, 12, None),
    "d-o-a-1950": ("plantowatch", None, 18, None),
    "gulliver-s-travels-1939": ("plantowatch", None, 25, None),
    "a-trip-to-the-moon-1902": ("plantowatch", None, 33, None),
    "nanook-of-the-north-1922": ("plantowatch", None, 40, None),
    "the-phantom-of-the-opera-1925": ("plantowatch", None, 5, None),
    "beat-the-devil-1953": ("plantowatch", None, 15, None),
    "plan-9-from-outer-space-1959": ("dropped", None, 140, 100),
    "reefer-madness-1936": ("dropped", None, 160, 120),
    "the-brain-that-wouldn-t-die-1962": ("dropped", None, 175, 130),
    "a-farewell-to-arms-1932": ("dropped", None, 190, 150),
}

# TV: key -> dict(status, watched, total, rating|None, added_days,
#                 next=(title, season, episode, days_ago) | None)
TV = {
    "the-cisco-kid-1950": dict(status="watching", watched=12, total=156, added=40,
                               next=("Ghost Town", 2, 3, 4)),
    "alcoa-presents-one-step-beyond-1959": dict(status="watching", watched=7, total=96, added=55,
                               next=("The Dark Room", 1, 8, 6)),
    "the-lone-ranger-1949": dict(status="watching", watched=30, total=221, added=120,
                               next=("The Renegades", 2, 5, 9)),
    "sherlock-holmes-1954-tv-series-1954": dict(status="watching", watched=5, total=39, added=20,
                               next=("The Case of the Belligerent Ghost", 1, 6, 2)),
    "the-beverly-hillbillies-1962": dict(status="watching", watched=4, total=274, added=14,
                               next=("Jed Buys Stock", 1, 5, 12)),
    "dragnet-1951": dict(status="completed", watched=276, total=276, rating=8, added=260),
    "the-red-skelton-show-1951": dict(status="completed", watched=120, total=120, rating=7, added=280),
    "you-bet-your-life-1950": dict(status="plantowatch", added=16),
    "the-george-burns-and-gracie-allen-show-1950": dict(status="hold", watched=20, total=291, added=180),
}

# Explore trending shelves (ordered). Keys must appear above.
TRENDING_MOVIES = [
    "the-general-1926", "his-girl-friday-1940", "charade-1963", "the-cabinet-of-dr-caligari-1920",
    "meet-john-doe-1941", "a-star-is-born-1937", "my-man-godfrey-1936", "the-kid-1921",
    "plan-9-from-outer-space-1959", "carnival-of-souls-1962", "detour-1945", "house-on-haunted-hill-1959",
]
TRENDING_SHOWS = [
    "the-cisco-kid-1950", "the-lone-ranger-1949", "sherlock-holmes-1954-tv-series-1954",
    "dragnet-1951", "the-beverly-hillbillies-1962", "alcoa-presents-one-step-beyond-1959",
    "the-red-skelton-show-1951", "you-bet-your-life-1950",
    "the-george-burns-and-gracie-allen-show-1950",
]


def display_title(title: str) -> str:
    return re.sub(r"\s*\(\d{4} TV series\)", "", title).strip()


def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> int:
    catalog = {c["key"]: c for c in json.loads(CATALOG.read_text())}

    # Validate every referenced key exists in the catalog and has a poster file.
    referenced = set(MOVIES) | set(TV) | set(TRENDING_MOVIES) | set(TRENDING_SHOWS)
    missing = [k for k in referenced if k not in catalog]
    if missing:
        print(f"error: keys not in catalog: {missing}", file=sys.stderr)
        return 1
    no_poster = [k for k in referenced if not (POSTERS / f"{k}.jpg").exists()]
    if no_poster:
        print(f"error: missing pd-posters/<key>.jpg for: {no_poster}", file=sys.stderr)
        return 1

    movie_rows, show_rows = [], []
    tmovie_rows, tshow_rows = [], []

    simkl = 900_101
    for key, (status, rating, added, watched) in MOVIES.items():
        c = catalog[key]
        args = [
            f"{simkl}", swift_str(display_title(c["title"])), f"{c['year']}",
            swift_str(key), swift_str(status),
        ]
        # Args must be in declaration order: rating, added, watched.
        kw = []
        if rating is not None:
            kw.append(f"rating: {rating}")
        kw.append(f"added: {added}")
        if watched is not None:
            kw.append(f"watched: {watched}")
        movie_rows.append(f"        movie({', '.join(args)}, {', '.join(kw)}),")
        simkl += 1

    simkl = 900_201
    for key, d in TV.items():
        c = catalog[key]
        args = [f"{simkl}", swift_str(display_title(c["title"])), f"{c['year']}",
                swift_str(key), swift_str(d["status"])]
        # Args must be in declaration order: watchedEps, totalEps, rating, added, next.
        kw = []
        if "watched" in d:
            kw.append(f'watchedEps: {d["watched"]}')
        if "total" in d:
            kw.append(f'totalEps: {d["total"]}')
        if "rating" in d:
            kw.append(f'rating: {d["rating"]}')
        kw.append(f'added: {d.get("added", 45)}')
        if d.get("next"):
            t, s, e, days = d["next"]
            kw.append(f'next: ({swift_str(t)}, {s}, {e}, {days})')
        show_rows.append(f"        show({', '.join(args)}, {', '.join(kw)}),")
        simkl += 1

    for i, key in enumerate(TRENDING_MOVIES, 1):
        c = catalog[key]
        tmovie_rows.append(
            f"        V1.TrendingMovies(simkl: {910_000 + i}, title: {swift_str(display_title(c['title']))}, "
            f"poster: {swift_str(key)}, order: {i}, year: {c['year']}),")
    for i, key in enumerate(TRENDING_SHOWS, 1):
        c = catalog[key]
        tshow_rows.append(
            f"        V1.TrendingShows(simkl: {920_000 + i}, title: {swift_str(display_title(c['title']))}, "
            f"poster: {swift_str(key)}, order: {i}, year: {c['year']}),")

    swift = TEMPLATE.format(
        movies="\n".join(movie_rows),
        shows="\n".join(show_rows),
        trending_movies="\n".join(tmovie_rows),
        trending_shows="\n".join(tshow_rows),
        n_movies=len(MOVIES), n_shows=len(TV),
    )
    OUT.write_text(swift)
    print(f"wrote {OUT} ({len(MOVIES)} movies, {len(TV)} shows, "
          f"{len(TRENDING_MOVIES)}+{len(TRENDING_SHOWS)} trending)")
    return 0


TEMPLATE = '''//
//  ScreenshotSeedData.swift
//  simalytics
//
//  GENERATED by marketing/app-store-screenshots/seed-fixtures.py — do not edit by
//  hand. DEBUG-only public-domain fixtures for the App Store screenshot pipeline.
//  Every title is a verified public-domain work (see pd-catalog.json) and every
//  `poster` value keys a local PD JPEG (pd-posters/<poster>.jpg) served by
//  ScreenshotMode.PosterURLProtocol — so no copyrighted artwork ever appears.
//  Simkl ids are synthetic (unique in-memory keys only).

#if DEBUG
  import Foundation
  import SwiftData

  enum ScreenshotSeedData {{
    static func seed(into context: ModelContext) {{
      for movie in movies() {{ context.insert(movie) }}
      for show in shows() {{ context.insert(show) }}
      for trending in trendingMovies() {{ context.insert(trending) }}
      for trending in trendingShows() {{ context.insert(trending) }}
      try? context.save()
    }}

    // ISO-8601 string `daysAgo` before now, so relative labels stay sensible.
    private static func iso(_ daysAgo: Int) -> String {{
      ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400)))
    }}

    // MARK: Movies (plantowatch / completed / dropped)

    private static func movies() -> [V1.SDMovies] {{
      [
{movies}
      ]
    }}

    private static func movie(
      _ simkl: Int, _ title: String, _ year: Int, _ poster: String, _ status: String,
      rating: Int? = nil, added: Int, watched: Int? = nil
    ) -> V1.SDMovies {{
      V1.SDMovies(
        simkl: simkl, title: title, added_to_watchlist_at: iso(added),
        release_date: "\\(year)-01-01",
        last_watched_at: watched.map {{ iso($0) }},
        user_rated_at: rating != nil ? iso(watched ?? added) : nil,
        status: status, user_rating: rating, poster: poster, year: year)
    }}

    // MARK: Shows (plantowatch / completed / hold / dropped / watching)
    // Watching rows carry next_to_watch_info_* so they populate Up Next.

    private static func shows() -> [V1.SDShows] {{
      [
{shows}
      ]
    }}

    private static func show(
      _ simkl: Int, _ title: String, _ year: Int, _ poster: String, _ status: String,
      watchedEps: Int? = nil, totalEps: Int? = nil, rating: Int? = nil, added: Int = 45,
      next: (title: String, season: Int, episode: Int, daysAgo: Int)? = nil
    ) -> V1.SDShows {{
      V1.SDShows(
        simkl: simkl, added_to_watchlist_at: iso(added), release_date: "\\(year)-01-01",
        last_watched_at: watchedEps != nil ? iso(next?.daysAgo ?? 30) : nil,
        user_rated_at: rating != nil ? iso(added) : nil, user_rating: rating,
        status: status, watched_episodes_count: watchedEps, total_episodes_count: totalEps,
        title: title, poster: poster, year: year,
        next_to_watch_info_title: next?.title,
        next_to_watch_info_season: next?.season,
        next_to_watch_info_episode: next?.episode,
        next_to_watch_info_date: next.map {{ iso($0.daysAgo) }})
    }}

    // MARK: Trending (Explore)

    private static func trendingMovies() -> [V1.TrendingMovies] {{
      [
{trending_movies}
      ]
    }}

    private static func trendingShows() -> [V1.TrendingShows] {{
      [
{trending_shows}
      ]
    }}
  }}
#endif
'''


if __name__ == "__main__":
    sys.exit(main())

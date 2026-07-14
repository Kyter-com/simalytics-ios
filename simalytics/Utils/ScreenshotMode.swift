//
//  ScreenshotMode.swift
//  simalytics
//
//  DEBUG-only support for the App Store screenshot pipeline
//  (marketing/app-store-screenshots). It lets `capture.sh` launch the app into a
//  fully populated, deterministic, OFFLINE state whose every visible poster is a
//  public-domain image we control — so nothing copyrighted from Simkl's CDN ever
//  appears in a marketing screenshot.
//
//  Everything here is compiled out of Release builds; the app's normal behavior
//  is untouched. Activation is driven entirely by launch environment variables
//  set by capture.sh:
//
//    SIMALYTICS_SCREENSHOTS=1                 enable screenshot fixture mode
//    SIMALYTICS_SCREENSHOT_TAB=<tab>          initial tab (lists|explore|upnext|settings)
//    SIMALYTICS_SCREENSHOT_POSTER_DIR=<path>  host dir of public-domain poster JPEGs
//
//  In screenshot mode:
//    - Auth is given a non-empty sentinel token so the Explore/Up Next gates open
//      (no real token, nothing is persisted to the keychain).
//    - The ModelContainer is in-memory and pre-seeded with public-domain fixtures
//      (see ScreenshotSeedData), so Lists/Up Next/Explore render real UI.
//    - `syncLatestActivities` is a no-op (see Sync.swift), so no network call can
//      overwrite the fixtures.
//    - Poster image requests are intercepted and served from local PD JPEGs.

#if DEBUG
  import Foundation
  import Kingfisher
  import SwiftData

  enum ScreenshotMode {
    /// True when capture.sh launched us in screenshot fixture mode.
    static var isActive: Bool {
      ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOTS"] == "1"
    }

    /// Non-empty placeholder so `auth.simklAccessToken.isEmpty` gates open. It is
    /// never sent to the network (sync is disabled in this mode) and never stored.
    static let sentinelToken = "SIMALYTICS_SCREENSHOT_MODE"

    /// Host directory holding the public-domain poster JPEGs, named `<key>.jpg`
    /// where `<key>` matches a fixture row's `poster` value.
    static var posterDirectory: String? {
      ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOT_POSTER_DIR"]
    }

    /// Optional sub-screen to render instead of a tab's default view, e.g.
    /// "movies-grid" opens the Movies "Completed" list forced to grid layout.
    static var screen: String? {
      ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOT_SCREEN"]
    }

    /// Per-capture toggle for the Anime section/shelf. Off (shown) by default;
    /// `capture.sh` sets it for the Explore slide so its trending-anime shelf, whose
    /// only PD art is early B&W, doesn't sit among the color shelves.
    static var hideAnime: Bool {
      ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOT_HIDE_ANIME"] == "1"
    }

    /// One-time setup for screenshot mode: force grid layout for the poster-wall
    /// slide, hide the (unseeded) Anime section/shelf, and route poster fetches
    /// through local PD JPEGs.
    static func setUp() {
      guard isActive else { return }
      UserDefaults.standard.set(ListLayout.grid.rawValue, forKey: "movieListLayout")
      UserDefaults.standard.set(ListLayout.grid.rawValue, forKey: "tvListLayout")
      // Anime visibility is per-capture (SIMALYTICS_SCREENSHOT_HIDE_ANIME=1): the
      // Lists slide shows the Anime section, but the Explore slide hides the Trending
      // Anime shelf (its posters are early B&W and would clash with the color shelves).
      UserDefaults.standard.set(hideAnime, forKey: "hideAnime")
      installPosterInterceptor()
    }

    /// An in-memory store pre-seeded with the public-domain fixtures.
    static func makeSeededContainer() -> ModelContainer {
      let schema = Schema(V1.models)
      let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      do {
        let container = try ModelContainer(for: schema, configurations: configuration)
        // A fresh context (not the main-actor `mainContext`) so seeding works from
        // the nonisolated container initializer.
        ScreenshotSeedData.seed(into: ModelContext(container))
        return container
      } catch {
        fatalError("Failed to build screenshot ModelContainer: \(error)")
      }
    }

    /// Route Kingfisher's poster fetches through `PosterURLProtocol` so every
    /// poster is a local public-domain image instead of a Simkl CDN asset.
    static func installPosterInterceptor() {
      guard isActive, posterDirectory != nil else { return }
      let configuration = ImageDownloader.default.sessionConfiguration
      var protocols = configuration.protocolClasses ?? []
      protocols.insert(PosterURLProtocol.self, at: 0)
      configuration.protocolClasses = protocols
      ImageDownloader.default.sessionConfiguration = configuration
    }
  }

  /// Serves local public-domain images for any Simkl poster or fanart request.
  ///
  /// The app builds poster URLs as `.../posters/<key>_m.jpg` and detail-view fanart
  /// banners as `.../fanart/<key>_mobile.jpg`; this protocol pulls `<key>` out of the
  /// path and returns `<posterDirectory>/<key>.jpg`. If the key has no matching file
  /// it fails the request, so the app falls back to its own placeholder rather than
  /// ever reaching the network. (Fanart keys use a distinct `<poster>-fanart` name so
  /// the portrait poster and its landscape banner don't collide on one filename.)
  final class PosterURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
      guard ScreenshotMode.posterDirectory != nil,
        let url = request.url?.absoluteString
      else { return false }
      return url.contains("/posters/") || url.contains("/fanart/")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
      guard
        let directory = ScreenshotMode.posterDirectory,
        let absolute = request.url?.absoluteString,
        let key = Self.posterKey(from: absolute),
        let data = FileManager.default.contents(
          atPath: (directory as NSString).appendingPathComponent("\(key).jpg"))
      else {
        client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
        return
      }
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "image/jpeg"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// `https://wsrv.nl/?url=https://simkl.in/posters/nosferatu-1922_m.jpg`
    /// -> `nosferatu-1922`, and
    /// `https://wsrv.nl/?url=https://simkl.in/fanart/the-general-1926-fanart_mobile.jpg`
    /// -> `the-general-1926-fanart`.
    static func posterKey(from absoluteURL: String) -> String? {
      let markers = ["/posters/", "/fanart/"]
      guard let marker = markers.first(where: { absoluteURL.contains($0) }),
        let range = absoluteURL.range(of: marker)
      else { return nil }
      var tail = String(absoluteURL[range.upperBound...])
      // `_mobile.jpg` first: it doesn't end in `_m.jpg`, so it must be matched
      // before the shorter poster suffixes.
      for suffix in ["_mobile.jpg", "_m.jpg", "_ca.jpg", "_w.jpg", ".jpg"] where tail.hasSuffix(suffix) {
        tail = String(tail.dropLast(suffix.count))
        break
      }
      return tail.isEmpty ? nil : tail.removingPercentEncoding ?? tail
    }
  }
#endif

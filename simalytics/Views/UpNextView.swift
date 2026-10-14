//
//  UpNextView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftData
import SwiftUI

protocol UpNextMedia {
  var simkl: Int { get }
  var title: String? { get }
  var poster: String? { get }
  var next_to_watch: String? { get }
  var next_to_watch_info_date: String? { get }
  var next_to_watch_info_title: String? { get }
  var next_to_watch_info_season: Int? { get }
  var next_to_watch_info_episode: Int? { get }
  var type: String { get }
}

extension V1.SDShows: UpNextMedia {
  var type: String { "tv" }
}
extension V1.SDAnimes: UpNextMedia {
  var type: String { "anime" }
  var next_to_watch_info_season: Int? { nil }
}

extension UpNextMedia {
  /// SIMKL's marker is authoritative; stale info or a future date is not watchable.
  func isAvailableUpNext(now: Date = Date()) -> Bool {
    guard let marker = next_to_watch,
      !marker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let selection = validatedSimklEpisode(
        season: next_to_watch_info_season, episode: next_to_watch_info_episode,
        fallbackSeason: type == "anime" ? 1 : nil
      ), selection.season > 0
    else { return false }
    guard let date = next_to_watch_info_date else { return true }
    guard let airDate = SimklDateParser.date(from: date) else { return false }
    return airDate <= now
  }

  /// Shared "S7 · E1" label for the next episode to watch.
  ///
  /// Used by both the grid badge and the long-press preview card so the two
  /// always agree. The spaced separator keeps VoiceOver from reading the
  /// season and episode as one run-together token.
  var nextEpisodeBadge: String? {
    var parts: [String] = []
    if let season = next_to_watch_info_season {
      parts.append("S\(season)")
    }
    if let episode = next_to_watch_info_episode {
      parts.append("E\(episode)")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}

struct UpNextView: View {
  @Environment(Auth.self) private var auth
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("upNextLayout") private var layout: ListLayout = .list
  @State private var searchText: String = ""
  @State private var updatingIDs: Set<Int> = []
  @State private var mutationError: String?
  @Environment(\.modelContext) private var context
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

  private func markWatched(_ mediaItem: any UpNextMedia) {
    // SIMKL serializes writes per user; allow only one Up Next action at a
    // time, including the following reconciliation, even across different rows.
    guard updatingIDs.isEmpty else { return }
    updatingIDs.insert(mediaItem.simkl)
    // The write and its resync can take a few seconds; show that work is running.
    globalLoadingIndicator.startSync()
    Task {
      defer {
        updatingIDs.remove(mediaItem.simkl)
        globalLoadingIndicator.stopSync()
      }
      let isAnime = mediaItem.type == "anime"
      guard
        let episodeSelection = validatedSimklEpisode(
          season: mediaItem.next_to_watch_info_season,
          episode: mediaItem.next_to_watch_info_episode,
          fallbackSeason: isAnime ? 1 : nil
        )
      else { return }

      invalidateUpNextCache(modelContainer: context.container)

      #if DEBUG
        // Exercise the same gesture offline without ever sending the sentinel token.
        if ScreenshotMode.isActive {
          optimisticallyClearNextToWatch(
            simklId: mediaItem.simkl, season: episodeSelection.season,
            episode: episodeSelection.episode, kind: isAnime ? .anime : .tv,
            modelContainer: context.container
          )
          return
        }
      #endif

      let result: SimklMutationResult
      if isAnime {
        result = await AnimeDetailView.markEpisodeWatched(
          auth.simklAccessToken,
          mediaItem.title ?? "",
          mediaItem.simkl,
          episodeSelection.season,
          episodeSelection.episode
        )
      } else {
        result = await ShowDetailView.markEpisodeWatched(
          auth.simklAccessToken,
          mediaItem.title ?? "",
          mediaItem.simkl,
          episodeSelection.season,
          episodeSelection.episode
        )
      }
      switch result {
      case .succeeded: break
      case .cancelled: return
      case .failed(let message):
        mutationError = message
        return
      }
      await syncLatestActivities(
        auth.simklAccessToken,
        modelContainer: context.container,
        forceRefresh: true
      )
    }
  }

  @ViewBuilder
  private func contextMenu(for mediaItem: any UpNextMedia) -> some View {
    Button {
      markWatched(mediaItem)
    } label: {
      Label("Mark Watched", systemImage: "checkmark.circle")
    }
    .disabled(!updatingIDs.isEmpty)
    ShareLink(
      item: URL(string: "https://simkl.com/\(mediaItem.type)/\(mediaItem.simkl)")!,
      subject: Text(mediaItem.title ?? ""),
      message: Text("Check out \(mediaItem.title ?? "this")!")
    ) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }

  @Query(
    filter: #Predicate<V1.SDShows> {
      (($0.next_to_watch ?? "") != "") && (($0.status ?? "") == "watching")
    }) private var shows: [V1.SDShows]

  @Query(
    filter: #Predicate<V1.SDAnimes> {
      (($0.next_to_watch ?? "") != "") && (($0.status ?? "") == "watching")
        && (($0.anime_type ?? "") == "tv")
    }
  ) private var animes: [V1.SDAnimes]

  var filteredMedia: [any UpNextMedia] {
    let candidates: [any UpNextMedia] = hideAnime ? Array(shows) : shows + animes
    let allMedia = candidates.filter { $0.isAvailableUpNext() }
    if searchText.isEmpty {
      return allMedia
    } else {
      return allMedia.filter { media in
        media.title?.localizedStandardContains(searchText) ?? false
          || (media.next_to_watch_info_title?.localizedStandardContains(searchText) ?? false)
      }
    }
  }

  var body: some View {
    NavigationStack {
      if auth.simklAccessToken.isEmpty {
        ContentUnavailableView {
          Label("Sign in to Simkl", systemImage: "lock.shield")
        } description: {
          Text("Sign in to Simkl to view your Up Next items.")
        }
      } else {
        Group {
          if filteredMedia.isEmpty {
            ContentUnavailableView {
              Label(
                searchText.isEmpty ? "Nothing Up Next" : "No Results",
                systemImage: searchText.isEmpty ? "play.tv" : "magnifyingglass")
            } description: {
              Text(
                searchText.isEmpty
                  ? "Episodes you are currently watching will appear here."
                  : "Try searching for another show or episode.")
            }
          } else if layout == .grid {
            ScrollView {
              LazyVGrid(columns: posterGridColumns, spacing: 16) {
                ForEach(filteredMedia, id: \.simkl) { mediaItem in
                  MediaDetailLink(sourceID: "upnext-\(mediaItem.simkl)") {
                    destinationView(for: mediaItem)
                  } label: {
                    PosterGridCell(
                      title: mediaItem.title ?? "",
                      poster: mediaItem.poster,
                      badge: mediaItem.nextEpisodeBadge
                    )
                    .overlay {
                      if updatingIDs.contains(mediaItem.simkl) { UpdatingIndicator() }
                    }
                  }
                  .buttonStyle(.plain)
                  .upNextGridSwipe(
                    item: mediaItem, markWatched: markWatched, disabled: !updatingIDs.isEmpty
                  )
                  .accessibilityAction(named: Text("Mark Watched")) { markWatched(mediaItem) }
                  .contextMenu {
                    contextMenu(for: mediaItem)
                  } preview: {
                    UpNextPreviewCard(mediaItem: mediaItem)
                  }
                }
              }
              .padding(.horizontal, posterGridHorizontalPadding)
              .padding(.vertical, 8)
            }
            .upNextSwipeContainer()
          } else {
            List(filteredMedia, id: \.simkl) { mediaItem in
              MediaDetailLink(sourceID: "upnext-\(mediaItem.simkl)") {
                destinationView(for: mediaItem)
              } label: {
                HStack {
                  // Keep the placeholder for missing art so every row's text lines up.
                  CustomKFImage(
                    imageUrlString: mediaItem.poster.map { "\(SIMKL_CDN_URL)/posters/\($0)_m.jpg" },
                    memoryCacheOnly: false,
                    height: 118,
                    width: 80
                  )

                  VStack(alignment: .leading) {
                    if let title = mediaItem.title {
                      Text(title)
                        .font(.headline)
                        .padding(.top, 8)
                    }
                    if let title = mediaItem.next_to_watch_info_title {
                      Text(title)
                        .font(.subheadline)
                    }
                    Spacer()
                    if let season = mediaItem.next_to_watch_info_season {
                      Text("Season \(season)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    if let episode = mediaItem.next_to_watch_info_episode {
                      Text("Episode \(episode)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                  }
                  if updatingIDs.contains(mediaItem.simkl) {
                    Spacer()
                    UpdatingIndicator()
                  }
                }
              }
              // Attach to the row, not the nested NavigationLink label, so
              // a full left swipe invokes the first action without another tap.
              // Only the action disables during updates; the row stays enabled
              // so detail navigation isn't blocked by the following resync.
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                  markWatched(mediaItem)
                } label: {
                  Label("Watched", systemImage: "checkmark.circle")
                }
                .tint(.green)
                .disabled(!updatingIDs.isEmpty)
              }
              .accessibilityAction(named: Text("Mark Watched")) { markWatched(mediaItem) }
              .contextMenu {
                contextMenu(for: mediaItem)
              } preview: {
                UpNextPreviewCard(mediaItem: mediaItem)
              }
            }
            .listStyle(.inset)
          }
        }
        .searchable(text: $searchText, placement: .automatic)
        .navigationTitle("Up Next")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            LayoutToggleButton(layout: $layout)
          }
          ToolbarItem(placement: .topBarTrailing) {
            if globalLoadingIndicator.isSyncing {
              ProgressView()
            }
          }
        }
      }
    }
    .alert(
      "Couldn’t Mark Watched",
      isPresented: Binding(
        get: { mutationError != nil },
        set: { if !$0 { mutationError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { mutationError = nil }
    } message: {
      Text(mutationError ?? "Please try again.")
    }
  }

  @ViewBuilder
  private func destinationView(for mediaItem: any UpNextMedia) -> some View {
    switch mediaItem.type {
    case "tv":
      ShowDetailView(simkl_id: mediaItem.simkl)
    case "anime":
      AnimeDetailView(simkl_id: mediaItem.simkl)
    default:
      ShowDetailView(simkl_id: mediaItem.simkl)
    }
  }
}

/// Shown on the row being marked watched until its resync finishes.
private struct UpdatingIndicator: View {
  var body: some View {
    ProgressView()
      .padding(10)
      .background(.regularMaterial, in: .circle)
      .accessibilityLabel("Marking watched")
  }
}

/// Swipe-to-mark-watched for Up Next poster-grid cells.
///
/// iOS 27 renders swipe actions on views outside List rows; earlier releases
/// skip this modifier entirely, so the grid keeps its context menu + preview
/// only. Mirrors the trailing "Watched" swipe already on the list rows.
private struct UpNextGridSwipe: ViewModifier {
  let item: any UpNextMedia
  let markWatched: (any UpNextMedia) -> Void
  let disabled: Bool

  func body(content: Content) -> some View {
    Group {
      if #available(iOS 27, *) {
        content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button {
            markWatched(item)
          } label: {
            Label("Watched", systemImage: "checkmark.circle")
          }
          .tint(.green)
          .disabled(disabled)
        }
      } else {
        content
      }
    }
  }
}

extension View {
  @ViewBuilder
  fileprivate func upNextSwipeContainer() -> some View {
    if #available(iOS 27, *) {
      swipeActionsContainer()
    } else {
      self
    }
  }

  fileprivate func upNextGridSwipe(
    item: any UpNextMedia, markWatched: @escaping (any UpNextMedia) -> Void, disabled: Bool
  ) -> some View {
    modifier(UpNextGridSwipe(item: item, markWatched: markWatched, disabled: disabled))
  }
}

// TODO: https://www.shutterstock.com/image-vector/s-letter-media-play-button-logo-1994243441
// TODO: https://www.logoground.com/logo.php?id=1027401

struct UpNextPreviewCard: View {
  let mediaItem: any UpNextMedia

  private var posterURL: String? {
    guard let poster = mediaItem.poster else { return nil }
    return "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg"
  }

  private var nextEpisodeText: String? {
    mediaItem.nextEpisodeBadge
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      CustomKFImage(
        imageUrlString: posterURL,
        memoryCacheOnly: true,
        height: 225,
        width: 150
      )

      VStack(alignment: .leading, spacing: 8) {
        Text(mediaItem.title ?? "Unknown")
          .font(.title2)
          .fontWeight(.bold)
          .lineLimit(3)

        HStack(spacing: 4) {
          Image(systemName: mediaItem.type == "anime" ? "sparkles.tv" : "tv")
          Text(mediaItem.type == "anime" ? "Anime" : "TV Show")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        if let episodeTitle = mediaItem.next_to_watch_info_title {
          Text(episodeTitle)
            .font(.subheadline)
            .lineLimit(2)
        }

        if let nextEp = nextEpisodeText {
          HStack(spacing: 4) {
            Image(systemName: "play.circle")
              .foregroundStyle(.blue)
            Text("Next: \(nextEp)")
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        Text("Watching")
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.2))
          .clipShape(Capsule())

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
    .padding(16)
    .frame(width: 350, height: 260)
    .background(Color(.systemBackground))
  }
}
